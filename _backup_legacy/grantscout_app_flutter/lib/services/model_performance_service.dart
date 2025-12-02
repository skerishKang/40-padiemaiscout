import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../models/llm_model.dart';

class ModelPerformanceService {
  static final ModelPerformanceService _instance = ModelPerformanceService._internal();
  factory ModelPerformanceService() => _instance;
  ModelPerformanceService._internal();

  // 모델 성능 데이터 조회
  Future<ModelPerformanceData> getModelPerformance({
    required String modelId,
    required String useCase,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('model_performance')
          .doc('${modelId}_${useCase}')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return ModelPerformanceData.fromMap(data);
      }

      // 기본값 반환
      return _getDefaultPerformanceData(modelId, useCase);
    } catch (e) {
      return _getDefaultPerformanceData(modelId, useCase);
    }
  }

  // 모델 성능 벤치마크 실행
  Future<BenchmarkResult> runBenchmark({
    required LLMModel model,
    required List<BenchmarkTask> tasks,
  }) async {
    final results = <TaskResult>[];
    double totalScore = 0.0;

    for (final task in tasks) {
      final result = await _executeBenchmarkTask(model, task);
      results.add(result);
      totalScore += result.score;
    }

    final averageScore = totalScore / tasks.length;
    final benchmarkResult = BenchmarkResult(
      modelId: model.id,
      modelName: model.name,
      useCase: _getUseCaseFromTasks(tasks),
      averageScore: averageScore,
      results: results,
      executedAt: DateTime.now(),
    );

    // 결과 저장
    await _saveBenchmarkResult(benchmarkResult);

    return benchmarkResult;
  }

  // 실시간 성능 테스트
  Future<RealtimeTestResult> testRealtimePerformance({
    required LLMModel model,
    required String prompt,
    Map<String, dynamic>? parameters,
  }) async {
    final startTime = DateTime.now();

    try {
      // API 호출 (실제 구현은 Cloud Functions에서)
      final response = await _callModelAPI(model, prompt, parameters);
      final endTime = DateTime.now();
      final responseTime = endTime.difference(startTime).inMilliseconds();

      // 응답 품질 평가
      final qualityScore = _evaluateResponseQuality(response, prompt);

      return RealtimeTestResult(
        modelId: model.id,
        modelName: model.name,
        prompt: prompt,
        response: response,
        responseTime: responseTime,
        qualityScore: qualityScore,
        timestamp: startTime,
        success: true,
      );
    } catch (e) {
      return RealtimeTestResult(
        modelId: model.id,
        modelName: model.name,
        prompt: prompt,
        response: '',
        responseTime: 0,
        qualityScore: 0.0,
        timestamp: startTime,
        success: false,
        error: e.toString(),
      );
    }
  }

  // 모델 비교 테스트
  Future<ModelComparisonResult> compareModels({
    required List<LLMModel> models,
    required String prompt,
    required String useCase,
  }) async {
    final results = <ModelTestResult>[];

    for (final model in models) {
      final testResult = await testRealtimePerformance(
        model: model,
        prompt: prompt,
      );

      results.add(ModelTestResult(
        model: model,
        testResult: testResult,
      ));
    }

    // 승자 결정
    results.sort((a, b) => b.testResult.qualityScore.compareTo(a.testResult.qualityScore));

    return ModelComparisonResult(
      prompt: prompt,
      useCase: useCase,
      results: results,
      executedAt: DateTime.now(),
    );
  }

  // A/B 테스트 설정
  Future<String> setupABTest({
    required String testId,
    required LLMModel modelA,
    required LLMModel modelB,
    required String trafficSplit, // '50/50', '70/30', etc.
    required String description,
  }) async {
    final testConfig = ABTestConfig(
      testId: testId,
      modelA: modelA,
      modelB: modelB,
      trafficSplit: trafficSplit,
      description: description,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final docRef = await FirebaseFirestore.instance
        .collection('ab_tests')
        .doc(testId);

    await docRef.set(testConfig.toMap());

    return testId;
  }

  // A/B 테스트 결과 기록
  Future<void> recordABTestResult({
    required String testId,
    required String userId,
    required String modelId,
    required String prompt,
    required String response,
    required double responseTime,
    required double userRating,
  }) async {
    await FirebaseFirestore.instance
        .collection('ab_test_results')
        .add({
      'testId': testId,
      'userId': userId,
      'modelId': modelId,
      'prompt': prompt,
      'response': response,
      'responseTime': responseTime,
      'userRating': userRating,
      'timestamp': Timestamp.now(),
    });
  }

  // A/B 테스트 분석
  Future<ABTestAnalysis> analyzeABTest(String testId) async {
    final resultsSnapshot = await FirebaseFirestore.instance
        .collection('ab_test_results')
        .where('testId', isEqualTo: testId)
        .get();

    final testDoc = await FirebaseFirestore.instance
        .collection('ab_tests')
        .doc(testId)
        .get();

    if (!testDoc.exists) {
      throw Exception('AB Test not found');
    }

    final testConfig = ABTestConfig.fromMap(testDoc.data() as Map<String, dynamic>);
    final results = resultsSnapshot.docs
        .map((doc) => ABTestResult.fromMap(doc.data() as Map<String, dynamic>))
        .toList();

    return _analyzeABTestResults(testConfig, results);
  }

  // 모델 성능 추이 추적
  Future<List<PerformanceTrend>> getPerformanceTrends({
    required String modelId,
    required String useCase,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('model_performance_trends')
        .where('modelId', isEqualTo: modelId)
        .where('useCase', isEqualTo: useCase)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate)))
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => PerformanceTrend.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  // 실시간 성능 모니터링
  Stream<RealtimeMetric> getRealtimeMetrics(String modelId) {
    return FirebaseFirestore.instance
        .collection('realtime_metrics')
        .where('modelId', isEqualTo: modelId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.docs.first.data() as Map<String, dynamic>;
          return RealtimeMetric.fromMap(data);
        });
  }

  // --- Private Helper Methods ---

  ModelPerformanceData _getDefaultPerformanceData(String modelId, String useCase) {
    switch (modelId) {
      case 'gemini-pro':
        return ModelPerformanceData(
          modelId: modelId,
          useCase: useCase,
          accuracy: 0.85,
          textAccuracy: 0.88,
          codeAccuracy: 0.82,
          analysisAccuracy: 0.86,
          koreanAccuracy: 0.90,
          averageResponseTime: 1.2,
          overallScore: 8.5,
          lastUpdated: DateTime.now(),
        );
      case 'gpt-4':
        return ModelPerformanceData(
          modelId: modelId,
          useCase: useCase,
          accuracy: 0.92,
          textAccuracy: 0.95,
          codeAccuracy: 0.90,
          analysisAccuracy: 0.91,
          koreanAccuracy: 0.85,
          averageResponseTime: 2.5,
          overallScore: 9.0,
          lastUpdated: DateTime.now(),
        );
      case 'gpt-3.5-turbo':
        return ModelPerformanceData(
          modelId: modelId,
          useCase: useCase,
          accuracy: 0.80,
          textAccuracy: 0.83,
          codeAccuracy: 0.78,
          analysisAccuracy: 0.81,
          koreanAccuracy: 0.82,
          averageResponseTime: 0.8,
          overallScore: 7.5,
          lastUpdated: DateTime.now(),
        );
      case 'claude-3-sonnet':
        return ModelPerformanceData(
          modelId: modelId,
          useCase: useCase,
          accuracy: 0.88,
          textAccuracy: 0.91,
          codeAccuracy: 0.85,
          analysisAccuracy: 0.89,
          koreanAccuracy: 0.83,
          averageResponseTime: 1.8,
          overallScore: 8.7,
          lastUpdated: DateTime.now(),
        );
      case 'clova-x':
        return ModelPerformanceData(
          modelId: modelId,
          useCase: useCase,
          accuracy: 0.82,
          textAccuracy: 0.85,
          codeAccuracy: 0.70,
          analysisAccuracy: 0.83,
          koreanAccuracy: 0.95,
          averageResponseTime: 1.5,
          overallScore: 8.2,
          lastUpdated: DateTime.now(),
        );
      default:
        return ModelPerformanceData(
          modelId: modelId,
          useCase: useCase,
          accuracy: 0.7,
          textAccuracy: 0.7,
          codeAccuracy: 0.7,
          analysisAccuracy: 0.7,
          koreanAccuracy: 0.7,
          averageResponseTime: 2.0,
          overallScore: 7.0,
          lastUpdated: DateTime.now(),
        );
    }
  }

  Future<TaskResult> _executeBenchmarkTask(LLMModel model, BenchmarkTask task) async {
    final startTime = DateTime.now();

    try {
      final response = await _callModelAPI(model, task.prompt, task.parameters);
      final endTime = DateTime.now();
      final responseTime = endTime.difference(startTime).inMilliseconds();

      final accuracy = _calculateAccuracy(response, task.expectedOutput);
      final qualityScore = _evaluateResponseQuality(response, task.prompt);

      return TaskResult(
        taskId: task.id,
        taskType: task.type,
        prompt: task.prompt,
        expectedOutput: task.expectedOutput,
        actualOutput: response,
        responseTime: responseTime,
        accuracy: accuracy,
        qualityScore: qualityScore,
        score: (accuracy + qualityScore) / 2,
      );
    } catch (e) {
      return TaskResult(
        taskId: task.id,
        taskType: task.type,
        prompt: task.prompt,
        expectedOutput: task.expectedOutput,
        actualOutput: '',
        responseTime: 0,
        accuracy: 0.0,
        qualityScore: 0.0,
        score: 0.0,
        error: e.toString(),
      );
    }
  }

  Future<String> _callModelAPI(LLMModel model, String prompt, Map<String, dynamic>? parameters) async {
    // 실제 API 호출 구현 (Cloud Functions)
    // 여기서는 Mock 데이터 반환
    await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(1000)));

    return 'Mock response for ${model.name}: $prompt';
  }

  double _calculateAccuracy(String actual, String expected) {
    // 정확도 계산 로직
    final actualWords = actual.toLowerCase().split(' ');
    final expectedWords = expected.toLowerCase().split(' ');

    int matches = 0;
    for (final word in expectedWords) {
      if (actualWords.contains(word)) {
        matches++;
      }
    }

    return expectedWords.isNotEmpty ? matches / expectedWords.length : 0.0;
  }

  double _evaluateResponseQuality(String response, String prompt) {
    // 응답 품질 평가 로직 (길이, 관련성, 완성도 등)
    double score = 0.5; // 기본 점수

    // 길이 적절성
    if (response.length >= 50 && response.length <= 1000) {
      score += 0.2;
    }

    // 프롬프트 관련성
    if (response.toLowerCase().contains(prompt.toLowerCase().split(' ').first)) {
      score += 0.2;
    }

    // 구조적 완성도
    if (response.contains('.') && response.contains(' ')) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  String _getUseCaseFromTasks(List<BenchmarkTask> tasks) {
    if (tasks.isNotEmpty) {
      return tasks.first.type;
    }
    return 'general';
  }

  Future<void> _saveBenchmarkResult(BenchmarkResult result) async {
    await FirebaseFirestore.instance
        .collection('benchmark_results')
        .add(result.toMap());

    // 성능 추이 데이터 저장
    await _updatePerformanceTrends(result);
  }

  Future<void> _updatePerformanceTrends(BenchmarkResult result) async {
    final trend = PerformanceTrend(
      modelId: result.modelId,
      useCase: result.useCase,
      score: result.averageScore,
      responseTime: result.results
          .map((r) => r.responseTime)
          .reduce((a, b) => a + b) / result.results.length,
      timestamp: result.executedAt,
    );

    await FirebaseFirestore.instance
        .collection('model_performance_trends')
        .add(trend.toMap());
  }

  ABTestAnalysis _analyzeABTestResults(ABTestConfig config, List<ABTestResult> results) {
    final modelAResults = results.where((r) => r.modelId == config.modelA.id).toList();
    final modelBResults = results.where((r) => r.modelId == config.modelB.id).toList();

    final modelAAvgScore = modelAResults.isEmpty
        ? 0.0
        : modelAResults.map((r) => r.userRating).reduce((a, b) => a + b) / modelAResults.length;

    final modelBAvgScore = modelBResults.isEmpty
        ? 0.0
        : modelBResults.map((r) => r.userRating).reduce((a, b) => a + b) / modelBResults.length;

    final modelAAvgTime = modelAResults.isEmpty
        ? 0.0
        : modelAResults.map((r) => r.responseTime).reduce((a, b) => a + b) / modelAResults.length;

    final modelBAvgTime = modelBResults.isEmpty
        ? 0.0
        : modelBResults.map((r) => r.responseTime).reduce((a, b) => a + b) / modelBResults.length;

    double statisticalSignificance = 0.0;
    if (modelAResults.isNotEmpty && modelBResults.isNotEmpty) {
      statisticalSignificance = _calculateStatisticalSignificance(
        modelAResults.map((r) => r.userRating).toList(),
        modelBResults.map((r) => r.userRating).toList(),
      );
    }

    String winner = 'tie';
    if (modelAAvgScore > modelBAvgScore) {
      winner = 'Model A';
    } else if (modelBAvgScore > modelAAvgScore) {
      winner = 'Model B';
    }

    return ABTestAnalysis(
      testId: config.testId,
      description: config.description,
      modelA: ModelTestSummary(
        modelId: config.modelA.id,
        modelName: config.modelA.name,
        avgScore: modelAAvgScore,
        avgResponseTime: modelAAvgTime,
        totalUsers: modelAResults.length,
      ),
      modelB: ModelTestSummary(
        modelId: config.modelB.id,
        modelName: config.modelB.name,
        avgScore: modelBAvgScore,
        avgResponseTime: modelBAvgTime,
        totalUsers: modelBResults.length,
      ),
      winner: winner,
      statisticalSignificance: statisticalSignificance,
      confidenceLevel: statisticalSignificance > 0.95 ? 'high' : 'medium',
      recommendations: _generateRecommendations(config, modelAAvgScore, modelBAvgScore),
    );
  }

  double _calculateStatisticalSignificance(List<double> sampleA, List<double> sampleB) {
    // 간단 t-검정 계산 (단순화된 버전)
    if (sampleA.length < 30 || sampleB.length < 30) {
      return 0.0; // 샘플이 너무 작으면 의미 없음
    }

    final meanA = sampleA.reduce((a, b) => a + b) / sampleA.length;
    final meanB = sampleB.reduce((a, b) => a + b) / sampleB.length;

    final varianceA = sampleA.map((x) => pow(x - meanA, 2)).reduce((a, b) => a + b) / (sampleA.length - 1);
    final varianceB = sampleB.map((x) => pow(x - meanB, 2)).reduce((a, b) => a + b) / (sampleB.length - 1);

    final pooledVariance = ((sampleA.length - 1) * varianceA + (sampleB.length - 1) * varianceB) /
                     (sampleA.length + sampleB.length - 2);

    final standardError = sqrt(pooledVariance * (1 / sampleA.length + 1 / sampleB.length));
    final tStatistic = (meanA - meanB) / standardError;

    // 간단 t-검정 p-value 근사
    return _tTestTwoTail(tStatistic, sampleA.length + sampleB.length - 2);
  }

  double _tTestTwoTail(double tStatistic, int degreesOfFreedom) {
    // 실제 t-분포 누적 함수를 사용해야 하지만 여기서는 근사치값 반환
    if (degreesOfFreedom >= 30) {
      // 자유도가 크면 정규분포로 근사
      return 2 * (1 - _normalCDF(tStatistic.abs()));
    }
    // 정확한 t-분포 계산 필요
    return _tCDF(tStatistic.abs()) * 2;
  }

  double _normalCDF(double x) {
    // 정규분포 누적분포 함수 근사
    return 0.5 * (1 + _erf(x / sqrt(2)));
  }

  double _erf(double x) {
    // 오차 함수 근사
    // 실제 구현에는 더 정밀한 근사 필요
    final t = 1.0 / (1.0 + 0.5 * x.abs());
    final tau = 1.0 / (2.0 * 3.141592592653);
    return _sign(x) * (1.0 - t * exp(-x * x - 1.26551223)) * _tanh(x * tau) * exp(-x * x - 1.26551223);
  }

  double _sign(double x) {
    return x < 0 ? -1.0 : 1.0;
  }

  List<String> _generateRecommendations(ABTestConfig config, double scoreA, double scoreB) {
    final recommendations = <String>[];
    final scoreDifference = (scoreA - scoreB).abs();

    if (scoreDifference < 0.1) {
      recommendations.add('두 모델의 성능이 비슷하여 비용 효율을 고려해보세요.');
    } else if (scoreA > scoreB) {
      recommendations.add('Model A가 성능이 우수하나, 비용을 확인해보세요.');
    } else {
      recommendations.add('Model B가 성능이 우수하나, 비용을 확인해보세요.');
    }

    if (scoreDifference > 0.3) {
      recommendations.add('성능 차이가 크므로 우수한 모델을 선택하세요.');
    }

    recommendations.add('추가 테스트를 통해 안정성을 확인하세요.');

    return recommendations;
  }
}

// 데이터 모델들
class ModelPerformanceData {
  final String modelId;
  final String useCase;
  final double accuracy;
  final double textAccuracy;
  final double codeAccuracy;
  final double analysisAccuracy;
  final double koreanAccuracy;
  final double averageResponseTime;
  final double overallScore;
  final DateTime lastUpdated;

  const ModelPerformanceData({
    required this.modelId,
    required this.useCase,
    required this.accuracy,
    required this.textAccuracy,
    required this.codeAccuracy,
    required this.analysisAccuracy,
    required this.koreanAccuracy,
    required this.averageResponseTime,
    required this.overallScore,
    required this.lastUpdated,
  });

  factory ModelPerformanceData.fromMap(Map<String, dynamic> map) {
    return ModelPerformanceData(
      modelId: map['modelId'] ?? '',
      useCase: map['useCase'] ?? '',
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      textAccuracy: (map['textAccuracy'] as num?)?.toDouble() ?? 0.0,
      codeAccuracy: (map['codeAccuracy'] as num?)?.toDouble() ?? 0.0,
      analysisAccuracy: (map['analysisAccuracy'] as num?)?.toDouble() ?? 0.0,
      koreanAccuracy: (map['koreanAccuracy'] as num?)?.toDouble() ?? 0.0,
      averageResponseTime: (map['averageResponseTime'] as num?)?.toDouble() ?? 0.0,
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'modelId': modelId,
      'useCase': useCase,
      'accuracy': accuracy,
      'textAccuracy': textAccuracy,
      'codeAccuracy': codeAccuracy,
      'analysisAccuracy': analysisAccuracy,
      'koreanAccuracy': koreanAccuracy,
      'averageResponseTime': averageResponseTime,
      'overallScore': overallScore,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

class BenchmarkTask {
  final String id;
  final String type;
  final String prompt;
  final String expectedOutput;
  final Map<String, dynamic> parameters;

  const BenchmarkTask({
    required this.id,
    required this.type,
    required this.prompt,
    required this.expectedOutput,
    this.parameters = const {},
  });
}

class TaskResult {
  final String taskId;
  final String taskType;
  final String prompt;
  final String expectedOutput;
  final String actualOutput;
  final int responseTime;
  final double accuracy;
  final double qualityScore;
  final double score;
  final String? error;

  const TaskResult({
    required this.taskId,
    required this.taskType,
    required this.prompt,
    required this.expectedOutput,
    required this.actualOutput,
    required this.responseTime,
    required this.accuracy,
    required this.qualityScore,
    required this.score,
    this.error,
  });
}

class BenchmarkResult {
  final String modelId;
  final String modelName;
  final String useCase;
  final double averageScore;
  final List<TaskResult> results;
  final DateTime executedAt;

  const BenchmarkResult({
    required this.modelId,
    required this.modelName,
    required this.useCase,
    required this.averageScore,
    required this.results,
    required this.executedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'modelId': modelId,
      'modelName': modelName,
      'useCase': useCase,
      'averageScore': averageScore,
      'results': results.map((r) => r.toMap()).toList(),
      'executedAt': Timestamp.fromDate(executedAt),
    };
  }
}

class RealtimeTestResult {
  final String modelId;
  final String modelName;
  final String prompt;
  final String response;
  final int responseTime;
  final double qualityScore;
  final DateTime timestamp;
  final bool success;
  final String? error;

  const RealtimeTestResult({
    required this.modelId,
    required this.modelName,
    required this.prompt,
    required this.response,
    required this.responseTime,
    required this.qualityScore,
    required this.timestamp,
    required this.success,
    this.error,
  });
}

class ModelComparisonResult {
  final String prompt;
  final String useCase;
  final List<ModelTestResult> results;
  final DateTime executedAt;

  const ModelComparisonResult({
    required this.prompt,
    required this.useCase,
    required this.results,
    required this.executedAt,
  });
}

class ModelTestResult {
  final LLMModel model;
  final RealtimeTestResult testResult;

  const ModelTestResult({
    required this.model,
    required this.testResult,
  });
}

class ABTestConfig {
  final String testId;
  final LLMModel modelA;
  final LLMModel modelB;
  final String trafficSplit;
  final String description;
  final bool isActive;
  final DateTime createdAt;

  const ABTestConfig({
    required this.testId,
    required this.modelA,
    required this.modelB,
    required this.trafficSplit,
    required this.description,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'testId': testId,
      'modelAId': modelA.id,
      'modelBId': modelB.id,
      'trafficSplit': trafficSplit,
      'description': description,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ABTestConfig.fromMap(Map<String, dynamic> map) {
    return ABTestConfig(
      testId: map['testId'] ?? '',
      modelA: LLMModel.getAllModels().firstWhere(
        (m) => m.id == map['modelAId'],
        orElse: () => LLMModel.geminiPro(),
      ),
      modelB: LLMModel.getAllModels().firstWhere(
        (m) => m.id == map['modelBId'],
        orElse: () => LLMModel.gpt4(),
      ),
      trafficSplit: map['trafficSplit'] ?? '50/50',
      description: map['description'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ABTestResult {
  final String testId;
  final String userId;
  final String modelId;
  final String prompt;
  final String response;
  final double responseTime;
  final double userRating;
  final Timestamp timestamp;

  const ABTestResult({
    required this.testId,
    required this.userId,
    required this.modelId,
    required this.prompt,
    required this.response,
    required this.responseTime,
    required this.userRating,
    required this.timestamp,
  });

  factory ABTestResult.fromMap(Map<String, dynamic> map) {
    return ABTestResult(
      testId: map['testId'] ?? '',
      userId: map['userId'] ?? '',
      modelId: map['modelId'] ?? '',
      prompt: map['prompt'] ?? '',
      response: map['response'] ?? '',
      responseTime: (map['responseTime'] as num?)?.toDouble() ?? 0.0,
      userRating: (map['userRating'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] as Timestamp,
    );
  }
}

class ABTestAnalysis {
  final String testId;
  final String description;
  final ModelTestSummary modelA;
  final ModelTestSummary modelB;
  final String winner;
  final double statisticalSignificance;
  final String confidenceLevel;
  final List<String> recommendations;

  const ABTestAnalysis({
    required this.testId,
    required this.description,
    required this.modelA,
    required this.modelB,
    required this.winner,
    required this.statisticalSignificance,
    required this.confidenceLevel,
    required this.recommendations,
  });
}

class ModelTestSummary {
  final String modelId;
  final String modelName;
  final double avgScore;
  final double avgResponseTime;
  final int totalUsers;

  const ModelTestSummary({
    required this.modelId,
    required this.modelName,
    required this.avgScore,
    required this.avgResponseTime,
    required this.totalUsers,
  });
}

class PerformanceTrend {
  final String modelId;
  final String useCase;
  final double score;
  final double responseTime;
  final DateTime timestamp;

  const PerformanceTrend({
    required this.modelId,
    required this.useCase,
    required this.score,
    required this.responseTime,
    required this.timestamp,
  });

  factory PerformanceTrend.fromMap(Map<String, dynamic> map) {
    return PerformanceTrend(
      modelId: map['modelId'] ?? '',
      useCase: map['useCase'] ?? '',
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      responseTime: (map['responseTime'] as num?)?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'modelId': modelId,
      'useCase': useCase,
      'score': score,
      'responseTime': responseTime,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class RealtimeMetric {
  final String modelId;
  final String metricName;
  final double value;
  final String unit;
  final DateTime timestamp;

  const RealtimeMetric({
    required this.modelId,
    required this.metricName,
    required this.value,
    required this.unit,
    required this.timestamp,
  });

  factory RealtimeMetric.fromMap(Map<String, dynamic> map) {
    return RealtimeMetric(
      modelId: map['modelId'] ?? '',
      metricName: map['metricName'] ?? '',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}