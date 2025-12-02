import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:collection/collection.dart';

class PredictionModel {
  final String id;
  final String name;
  final String description;
  final PredictionType type;
  final Map<String, double> weights;
  final Map<String, dynamic> parameters;
  final double accuracy;
  final Timestamp trainedAt;
  final bool isActive;

  const PredictionModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.weights,
    this.parameters = const {},
    required this.accuracy,
    required this.trainedAt,
    this.isActive = true,
  });
}

enum PredictionType {
  grantSuccess('지원사업 성공률 예측'),
  matchingScore('매칭 점수 예측'),
  deadlineRisk('마감일 리스크 예측'),
  marketTrend('시장 트렌드 예측'),
  competitionLevel('경쟁 수준 예측'),
  fundingAmount('지원금 예측'),
  industryGrowth('산업 성장성 예측');

  const PredictionType(this.displayName);
  final String displayName;
}

class PredictionResult {
  final String id;
  final String modelId;
  final String targetId; // 예측 대상 ID (지원사업, 파일 등)
  final PredictionType type;
  final double confidence;
  final Map<String, dynamic> prediction;
  final Map<String, double> factors;
  final String explanation;
  final List<String> recommendations;
  final Timestamp createdAt;

  const PredictionResult({
    required this.id,
    required this.modelId,
    required this.targetId,
    required this.type,
    required this.confidence,
    required this.prediction,
    required this.factors,
    required this.explanation,
    required this.recommendations,
    required this.createdAt,
  });
}

class PredictionEngine {
  static final PredictionEngine _instance = PredictionEngine._internal();
  factory PredictionEngine() => _instance;
  PredictionEngine._internal();

  // 지원사업 성공률 예측
  Future<PredictionResult> predictGrantSuccess({
    required String grantId,
    required Map<String, dynamic> userProfile,
    required Map<String, dynamic> fileAnalysis,
  }) async {
    final features = _extractSuccessFeatures(userProfile, fileAnalysis);
    final weights = await _getModelWeights('grant_success');

    // 가중합 계산
    double score = 0.0;
    final factors = <String, double>{};

    features.forEach((key, value) {
      final weight = weights[key] ?? 0.0;
      final contribution = value * weight;
      score += contribution;
      factors[key] = contribution;
    });

    // 시그모이드 함수로 확률 변환
    final probability = _sigmoid(score);

    // 신뢰도 계산
    final confidence = _calculateConfidence(features, weights);

    // 설명 생성
    final explanation = _generateSuccessExplanation(factors, probability);
    final recommendations = _generateSuccessRecommendations(factors, probability);

    return PredictionResult(
      id: _generateId(),
      modelId: 'grant_success_model',
      targetId: grantId,
      type: PredictionType.grantSuccess,
      confidence: confidence,
      prediction: {
        'success_probability': probability,
        'risk_level': _getRiskLevel(probability),
        'recommended_action': _getRecommendedAction(probability),
      },
      factors: factors,
      explanation: explanation,
      recommendations: recommendations,
      createdAt: Timestamp.now(),
    );
  }

  // 매칭 점수 예측
  Future<PredictionResult> predictMatchingScore({
    required Map<String, dynamic> grantData,
    required Map<String, dynamic> userProfile,
    required Map<String, dynamic> fileAnalysis,
  }) async {
    final features = _extractMatchingFeatures(grantData, userProfile, fileAnalysis);
    final weights = await _getModelWeights('matching_score');

    double score = 0.0;
    final factors = <String, double>{};

    features.forEach((key, value) {
      final weight = weights[key] ?? 0.0;
      final contribution = value * weight;
      score += contribution;
      factors[key] = contribution;
    });

    // 점수 정규화 (0-100)
    final normalizedScore = (score * 100).clamp(0.0, 100.0);
    final confidence = _calculateConfidence(features, weights);

    final explanation = _generateMatchingExplanation(factors, normalizedScore);
    final recommendations = _generateMatchingRecommendations(factors, normalizedScore);

    return PredictionResult(
      id: _generateId(),
      modelId: 'matching_score_model',
      targetId: grantData['id'] ?? '',
      type: PredictionType.matchingScore,
      confidence: confidence,
      prediction: {
        'matching_score': normalizedScore,
        'compatibility_level': _getCompatibilityLevel(normalizedScore),
        'improvement_areas': _getImprovementAreas(factors),
      },
      factors: factors,
      explanation: explanation,
      recommendations: recommendations,
      createdAt: Timestamp.now(),
    );
  }

  // 마감일 리스크 예측
  Future<PredictionResult> predictDeadlineRisk({
    required String grantId,
    required DateTime deadline,
    required Map<String, dynamic> userProfile,
    required List<Map<String, dynamic>> historicalData,
  }) async {
    final daysUntilDeadline = deadline.difference(DateTime.now()).inDays;
    final features = _extractDeadlineFeatures(daysUntilDeadline, userProfile, historicalData);
    final weights = await _getModelWeights('deadline_risk');

    double riskScore = 0.0;
    final factors = <String, double>{};

    features.forEach((key, value) {
      final weight = weights[key] ?? 0.0;
      final contribution = value * weight;
      riskScore += contribution;
      factors[key] = contribution;
    });

    final normalizedRisk = (riskScore * 100).clamp(0.0, 100.0);
    final confidence = _calculateConfidence(features, weights);

    final explanation = _generateDeadlineExplanation(factors, normalizedRisk, daysUntilDeadline);
    final recommendations = _generateDeadlineRecommendations(normalizedRisk, daysUntilDeadline);

    return PredictionResult(
      id: _generateId(),
      modelId: 'deadline_risk_model',
      targetId: grantId,
      type: PredictionType.deadlineRisk,
      confidence: confidence,
      prediction: {
        'risk_score': normalizedRisk,
        'risk_level': _getRiskLevelFromScore(normalizedRisk),
        'optimal_start_date': _calculateOptimalStartDate(deadline, userProfile),
        'buffer_days_needed': _calculateBufferDays(normalizedRisk),
      },
      factors: factors,
      explanation: explanation,
      recommendations: recommendations,
      createdAt: Timestamp.now(),
    );
  }

  // 시장 트렌드 예측
  Future<PredictionResult> predictMarketTrend({
    required String industry,
    required String region,
    required int timeframeMonths,
  }) async {
    final historicalData = await _getMarketHistoricalData(industry, region);
    final features = _extractMarketFeatures(historicalData, timeframeMonths);
    final weights = await _getModelWeights('market_trend');

    double trendScore = 0.0;
    final factors = <String, double>{};

    features.forEach((key, value) {
      final weight = weights[key] ?? 0.0;
      final contribution = value * weight;
      trendScore += contribution;
      factors[key] = contribution;
    });

    final trendDirection = _getTrendDirection(trendScore);
    final confidence = _calculateConfidence(features, weights);

    final explanation = _generateTrendExplanation(factors, trendDirection);
    final recommendations = _generateTrendRecommendations(trendDirection, industry);

    return PredictionResult(
      id: _generateId(),
      modelId: 'market_trend_model',
      targetId: '${industry}_${region}',
      type: PredictionType.marketTrend,
      confidence: confidence,
      prediction: {
        'trend_direction': trendDirection,
        'growth_rate': _calculateGrowthRate(trendScore),
        'market_opportunities': _identifyMarketOpportunities(features),
        'potential_risks': _identifyMarketRisks(features),
      },
      factors: factors,
      explanation: explanation,
      recommendations: recommendations,
      createdAt: Timestamp.now(),
    );
  }

  // 개인화 추천 엔진
  Future<List<Map<String, dynamic>>> generatePersonalizedRecommendations({
    required String userId,
    required Map<String, dynamic> userProfile,
    int limit = 10,
  }) async {
    final userHistory = await _getUserHistory(userId);
    final preferences = await _getUserPreferences(userId);
    final similarUsers = await _findSimilarUsers(userProfile);

    final recommendations = <Map<String, dynamic>>[];

    // 콘텐츠 기반 필터링
    final contentBased = await _contentBasedFiltering(userProfile, preferences);
    recommendations.addAll(contentBased);

    // 협업 필터링
    final collaborative = await _collaborativeFiltering(userId, similarUsers);
    recommendations.addAll(collaborative);

    // 하이브리드 추천
    final hybrid = await _hybridRecommendations(userProfile, userHistory, preferences);
    recommendations.addAll(hybrid);

    // 중복 제거 및 점수 정렬
    final uniqueRecommendations = _removeDuplicates(recommendations);
    uniqueRecommendations.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    return uniqueRecommendations.take(limit).toList();
  }

  // 피처 추출 메서드들
  Map<String, double> _extractSuccessFeatures(
    Map<String, dynamic> userProfile,
    Map<String, dynamic> fileAnalysis,
  ) {
    final features = <String, double>{};

    // 기업 규모
    final employeeCount = userProfile['employeeCount'] as int? ?? 0;
    features['company_size'] = _normalizeEmployeeCount(employeeCount);

    // 업력
    final foundedYear = userProfile['foundedYear'] as int? ?? DateTime.now().year;
    features['company_age'] = _normalizeCompanyAge(DateTime.now().year - foundedYear);

    // 산업 분류
    features['industry_alignment'] = _calculateIndustryAlignment(userProfile, fileAnalysis);

    // 재무 상태
    features['financial_stability'] = _calculateFinancialStability(userProfile);

    // 과거 성공률
    features['past_success_rate'] = userProfile['pastSuccessRate'] as double? ?? 0.0;

    // 기술 수준
    features['technology_level'] = _calculateTechnologyLevel(fileAnalysis);

    return features;
  }

  Map<String, double> _extractMatchingFeatures(
    Map<String, dynamic> grantData,
    Map<String, dynamic> userProfile,
    Map<String, dynamic> fileAnalysis,
  ) {
    final features = <String, double>{};

    // 키워드 매칭
    features['keyword_match'] = _calculateKeywordMatch(grantData, fileAnalysis);

    // 산업 적합성
    features['industry_fit'] = _calculateIndustryFit(grantData, userProfile);

    // 지역 적합성
    features['regional_fit'] = _calculateRegionalFit(grantData, userProfile);

    // 규모 적합성
    features['size_fit'] = _calculateSizeFit(grantData, userProfile);

    // 요구사항 충족도
    features['requirement_fulfillment'] = _calculateRequirementFulfillment(grantData, fileAnalysis);

    return features;
  }

  // 유틸리티 메서드들
  double _sigmoid(double x) {
    return 1.0 / (1.0 + exp(-x));
  }

  double _normalizeEmployeeCount(int count) {
    // 0-1000 사이를 0-1로 정규화
    return (count.clamp(0, 1000) / 1000.0);
  }

  double _normalizeCompanyAge(int age) {
    // 0-50년 사이를 0-1로 정규화
    return (age.clamp(0, 50) / 50.0);
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString();
  }

  double _calculateConfidence(Map<String, double> features, Map<String, double> weights) {
    // 피처와 가중치의 일관성을 기반으로 신뢰도 계산
    double totalWeight = 0.0;
    double usedWeight = 0.0;

    weights.forEach((key, weight) {
      totalWeight += weight.abs();
      if (features.containsKey(key)) {
        usedWeight += weight.abs();
      }
    });

    return totalWeight > 0 ? usedWeight / totalWeight : 0.0;
  }

  String _getRiskLevel(double probability) {
    if (probability >= 0.8) return '낮음';
    if (probability >= 0.6) return '보통';
    if (probability >= 0.4) return '높음';
    return '매우 높음';
  }

  String _getRecommendedAction(double probability) {
    if (probability >= 0.8) return '적극적으로 지원 추천';
    if (probability >= 0.6) return '지원 고려';
    if (probability >= 0.4) return '조건부 지원 가능';
    return '지원 보류 권장';
  }

  // Firestore 관련 메서드들
  Future<Map<String, double>> _getModelWeights(String modelType) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('prediction_models')
          .doc(modelType)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return Map<String, double>.from(data['weights'] ?? {});
      }
    } catch (e) {
      // 기본 가중치 반환
      return _getDefaultWeights(modelType);
    }

    return _getDefaultWeights(modelType);
  }

  Map<String, double> _getDefaultWeights(String modelType) {
    switch (modelType) {
      case 'grant_success':
        return {
          'company_size': 0.2,
          'company_age': 0.15,
          'industry_alignment': 0.25,
          'financial_stability': 0.2,
          'past_success_rate': 0.15,
          'technology_level': 0.05,
        };
      case 'matching_score':
        return {
          'keyword_match': 0.3,
          'industry_fit': 0.25,
          'regional_fit': 0.2,
          'size_fit': 0.15,
          'requirement_fulfillment': 0.1,
        };
      default:
        return {};
    }
  }

  // 설명 및 추천 생성 메서드들
  String _generateSuccessExplanation(Map<String, double> factors, double probability) {
    final topFactors = factors.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

    final buffer = StringBuffer();
    buffer.write('성공 확률 ${(probability * 100).toStringAsFixed(1)}% 예측.\n');

    if (topFactors.isNotEmpty) {
      buffer.write('주요 영향 요인:\n');
      for (int i = 0; i < min(3, topFactors.length); i++) {
        final factor = topFactors[i];
        buffer.write('- ${_getFactorDisplayName(factor.key)}: ${_formatImpact(factor.value)}\n');
      }
    }

    return buffer.toString();
  }

  List<String> _generateSuccessRecommendations(Map<String, double> factors, double probability) {
    final recommendations = <String>[];

    if (probability < 0.6) {
      recommendations.add('성공률을 높이기 위해 추가 자료를 준비하세요.');
      recommendations.add('핵심 요건을 더 충족시킬 수 있는 방안을 검토하세요.');
    }

    // 낮은 점수 요인 개선 추천
    factors.forEach((key, value) {
      if (value < 0.3) {
        recommendations.add(_getImprovementRecommendation(key));
      }
    });

    return recommendations;
  }

  String _getFactorDisplayName(String key) {
    final displayNames = {
      'company_size': '기업 규모',
      'company_age': '업력',
      'industry_alignment': '산업 적합성',
      'financial_stability': '재무 안정성',
      'past_success_rate': '과거 성공률',
      'technology_level': '기술 수준',
      'keyword_match': '키워드 일치도',
      'industry_fit': '산업 적합도',
      'regional_fit': '지역 적합도',
      'size_fit': '규모 적합도',
      'requirement_fulfillment': '요구사항 충족도',
    };
    return displayNames[key] ?? key;
  }

  String _formatImpact(double value) {
    final percentage = (value * 100).toStringAsFixed(1);
    return value > 0 ? '+$percentage%' : '$percentage%';
  }

  String _getImprovementRecommendation(String factor) {
    final recommendations = {
      'company_size': '규모 요건을 충족하기 위해 파트너사와 협력을 고려하세요.',
      'company_age': '업력 요건을 보완할 수 있는 실적을 추가로 준비하세요.',
      'industry_alignment': '산업 적합성을 높이기 위해 관련 프로젝트 경험을 강조하세요.',
      'financial_stability': '재무 제표를 보강하여 안정성을 증명하세요.',
      'past_success_rate': '유사한 성공 사례를 더 포함시켜 신뢰도를 높이세요.',
      'technology_level': '기술력을 입증할 수 있는 자료를 추가하세요.',
    };
    return recommendations[factor] ?? '해당 요소를 개선할 방안을 검토하세요.';
  }

  // 다른 예측 메서드들도 유사하게 구현...
  Future<Map<String, dynamic>> _getMarketHistoricalData(String industry, String region) async {
    // 시장 과거 데이터 조회 로직
    return {};
  }

  Future<List<Map<String, dynamic>>> _getUserHistory(String userId) async {
    // 사용자 히스토리 조회
    return [];
  }

  Future<Map<String, dynamic>> _getUserPreferences(String userId) async {
    // 사용자 선호도 조회
    return {};
  }

  Future<List<String>> _findSimilarUsers(Map<String, dynamic> userProfile) async {
    // 유사 사용자 찾기
    return [];
  }

  // 기타 보조 메서드들...
  double _calculateIndustryAlignment(Map<String, dynamic> userProfile, Map<String, dynamic> fileAnalysis) {
    // 산업 적합성 계산 로직
    return Random().nextDouble();
  }

  double _calculateFinancialStability(Map<String, dynamic> userProfile) {
    // 재무 안정성 계산 로직
    return Random().nextDouble();
  }

  double _calculateTechnologyLevel(Map<String, dynamic> fileAnalysis) {
    // 기술 수준 계산 로직
    return Random().nextDouble();
  }

  double _calculateKeywordMatch(Map<String, dynamic> grantData, Map<String, dynamic> fileAnalysis) {
    // 키워드 매칭 계산 로직
    return Random().nextDouble();
  }

  double _calculateIndustryFit(Map<String, dynamic> grantData, Map<String, dynamic> userProfile) {
    // 산업 적합도 계산 로직
    return Random().nextDouble();
  }

  double _calculateRegionalFit(Map<String, dynamic> grantData, Map<String, dynamic> userProfile) {
    // 지역 적합도 계산 로직
    return Random().nextDouble();
  }

  double _calculateSizeFit(Map<String, dynamic> grantData, Map<String, dynamic> userProfile) {
    // 규모 적합도 계산 로직
    return Random().nextDouble();
  }

  double _calculateRequirementFulfillment(Map<String, dynamic> grantData, Map<String, dynamic> fileAnalysis) {
    // 요구사항 충족도 계산 로직
    return Random().nextDouble();
  }

  // 나머지 메서드들도 유사하게 구현...
  String _generateMatchingExplanation(Map<String, double> factors, double score) => '매칭 점수: ${score.toStringAsFixed(1)}점';
  List<String> _generateMatchingRecommendations(Map<String, double> factors, double score) => ['추천사항'];
  String _generateDeadlineExplanation(Map<String, double> factors, double risk, int days) => '리스크 분석';
  List<String> _generateDeadlineRecommendations(double risk, int days) => ['마감일 관리'];
  String _getRiskLevelFromScore(double score) => '보통';
  DateTime _calculateOptimalStartDate(DateTime deadline, Map<String, dynamic> profile) => deadline.subtract(Duration(days: 30));
  int _calculateBufferDays(double risk) => risk > 70 ? 14 : 7;
  String _getTrendDirection(double score) => '상승';
  double _calculateGrowthRate(double score) => score * 0.1;
  List<String> _identifyMarketOpportunities(Map<String, dynamic> features) => ['기회'];
  List<String> _identifyMarketRisks(Map<String, dynamic> features) => ['리스크'];
  String _generateTrendExplanation(Map<String, double> factors, String direction) => '트렌드 분석';
  List<String> _generateTrendRecommendations(String direction, String industry) => ['추천사항'];

  Map<String, double> _extractDeadlineFeatures(int days, Map<String, dynamic> profile, List<Map<String, dynamic>> history) => {'time_pressure': days / 30.0};
  Map<String, double> _extractMarketFeatures(List<dynamic> data, int months) => {'growth_trend': 0.5};

  Future<List<Map<String, dynamic>>> _contentBasedFiltering(Map<String, dynamic> profile, Map<String, dynamic> prefs) async => [];
  Future<List<Map<String, dynamic>>> _collaborativeFiltering(String userId, List<String> similarUsers) async => [];
  Future<List<Map<String, dynamic>>> _hybridRecommendations(Map<String, dynamic> profile, List<dynamic> history, Map<String, dynamic> prefs) async => [];

  List<Map<String, dynamic>> _removeDuplicates(List<Map<String, dynamic>> recommendations) {
    final seen = <String>{};
    return recommendations.where((rec) {
      final id = rec['id'] as String;
      return seen.add(id);
    }).toList();
  }

  String _getCompatibilityLevel(double score) {
    if (score >= 80) return '매우 높음';
    if (score >= 60) return '높음';
    if (score >= 40) return '보통';
    if (score >= 20) return '낮음';
    return '매우 낮음';
  }

  List<String> _getImprovementAreas(Map<String, double> factors) {
    return factors.entries
        .where((entry) => entry.value < 0.5)
        .map((entry) => _getFactorDisplayName(entry.key))
        .toList();
  }
}