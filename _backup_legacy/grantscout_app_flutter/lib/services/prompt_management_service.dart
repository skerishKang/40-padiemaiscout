import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/llm_model.dart';

enum PromptCategory {
  grantAnalysis('지원사업 분석'),
  grantWriting('지원서 작성'),
  documentReview('문서 검토'),
  dataAnalysis('데이터 분석'),
  reportGeneration('보고서 생성'),
  translation('번역'),
  summarization('요약'),
  qa('질의응답'),
  brainstorming('아이디어 생성'),
  custom('사용자 정의');

  const PromptCategory(this.displayName);
  final String displayName;
}

enum PromptTemplateType {
  basic,
  structured,
  chainOfThought,
  fewShot,
  rolePlay,
  stepByStep,
}

class PromptTemplate {
  final String id;
  final String name;
  final String description;
  final PromptCategory category;
  final PromptTemplateType type;
  final String template;
  final List<String> variables;
  final List<String> examples;
  final Map<String, dynamic> metadata;
  final String? createdBy;
  final bool isPublic;
  final int usageCount;
  final double averageRating;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PromptTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.type,
    required this.template,
    required this.variables,
    this.examples = const [],
    this.metadata = const {},
    this.createdBy,
    this.isPublic = false,
    this.usageCount = 0,
    this.averageRating = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PromptTemplate.fromMap(Map<String, dynamic> map) {
    return PromptTemplate(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: PromptCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => PromptCategory.custom,
      ),
      type: PromptTemplateType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => PromptTemplateType.basic,
      ),
      template: map['template'] ?? '',
      variables: List<String>.from(map['variables'] ?? []),
      examples: List<String>.from(map['examples'] ?? []),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      createdBy: map['createdBy'],
      isPublic: map['isPublic'] ?? false,
      usageCount: map['usageCount'] ?? 0,
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.name,
      'type': type.name,
      'template': template,
      'variables': variables,
      'examples': examples,
      'metadata': metadata,
      'createdBy': createdBy,
      'isPublic': isPublic,
      'usageCount': usageCount,
      'averageRating': averageRating,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class PromptExecution {
  final String id;
  final String templateId;
  final String userId;
  final LLMModel model;
  final Map<String, dynamic> variables;
  final String finalPrompt;
  final String response;
  final int responseTime;
  final int tokenCount;
  final double cost;
  final double userRating;
  final String? feedback;
  final DateTime timestamp;

  const PromptExecution({
    required this.id,
    required this.templateId,
    required this.userId,
    required this.model,
    required this.variables,
    required this.finalPrompt,
    required this.response,
    required this.responseTime,
    required this.tokenCount,
    required this.cost,
    required this.userRating,
    this.feedback,
    required this.timestamp,
  });

  factory PromptExecution.fromMap(Map<String, dynamic> map) {
    return PromptExecution(
      id: map['id'] ?? '',
      templateId: map['templateId'] ?? '',
      userId: map['userId'] ?? '',
      model: LLMModel.getAllModels().firstWhere(
        (m) => m.id == map['modelId'],
        orElse: () => LLMModel.geminiPro(),
      ),
      variables: Map<String, dynamic>.from(map['variables'] ?? {}),
      finalPrompt: map['finalPrompt'] ?? '',
      response: map['response'] ?? '',
      responseTime: map['responseTime'] ?? 0,
      tokenCount: map['tokenCount'] ?? 0,
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
      userRating: (map['userRating'] as num?)?.toDouble() ?? 0.0,
      feedback: map['feedback'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'templateId': templateId,
      'userId': userId,
      'modelId': model.id,
      'variables': variables,
      'finalPrompt': finalPrompt,
      'response': response,
      'responseTime': responseTime,
      'tokenCount': tokenCount,
      'cost': cost,
      'userRating': userRating,
      'feedback': feedback,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class PromptManagementService {
  static final PromptManagementService _instance = PromptManagementService._internal();
  factory PromptManagementService() => _instance;
  PromptManagementService._internal();

  // 프롬프트 템플릿 관리
  Future<List<PromptTemplate>> getTemplates({
    String? userId,
    PromptCategory? category,
    bool? isPublic,
    String? searchQuery,
    int limit = 50,
  }) async {
    Query query = FirebaseFirestore.instance.collection('prompt_templates');

    if (userId != null) {
      query = query.where('createdBy', isEqualTo: userId);
    }

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    if (isPublic != null) {
      query = query.where('isPublic', isEqualTo: isPublic);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // 검색은 클라이언트 측에서 처리
    }

    query = query.orderBy('usageCount', descending: true).limit(limit);

    final snapshot = await query.get();
    var templates = snapshot.docs
        .map((doc) => PromptTemplate.fromMap(doc.data()))
        .toList();

    // 검색 필터링
    if (searchQuery != null && searchQuery.isNotEmpty) {
      templates = templates.where((template) {
        return template.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
            template.description.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    return templates;
  }

  Future<PromptTemplate?> getTemplate(String id) async {
    final doc = await FirebaseFirestore.instance
        .collection('prompt_templates')
        .doc(id)
        .get();

    if (doc.exists) {
      return PromptTemplate.fromMap(doc.data());
    }
    return null;
  }

  Future<String> createTemplate({
    required String name,
    required String description,
    required PromptCategory category,
    required PromptTemplateType type,
    required String template,
    required List<String> variables,
    List<String>? examples,
    Map<String, dynamic>? metadata,
    bool isPublic = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final docRef = FirebaseFirestore.instance
        .collection('prompt_templates')
        .doc();

    final promptTemplate = PromptTemplate(
      id: docRef.id,
      name: name,
      description: description,
      category: category,
      type: type,
      template: template,
      variables: variables,
      examples: examples ?? [],
      metadata: metadata ?? {},
      createdBy: user.uid,
      isPublic: isPublic,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(promptTemplate.toMap());
    return docRef.id;
  }

  Future<void> updateTemplate(String id, {
    String? name,
    String? description,
    PromptCategory? category,
    PromptTemplateType? type,
    String? template,
    List<String>? variables,
    List<String>? examples,
    Map<String, dynamic>? metadata,
    bool? isPublic,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (category != null) updates['category'] = category.name;
    if (type != null) updates['type'] = type.name;
    if (template != null) updates['template'] = template;
    if (variables != null) updates['variables'] = variables;
    if (examples != null) updates['examples'] = examples;
    if (metadata != null) updates['metadata'] = metadata;
    if (isPublic != null) updates['isPublic'] = isPublic;

    await FirebaseFirestore.instance
        .collection('prompt_templates')
        .doc(id)
        .update(updates);
  }

  Future<void> deleteTemplate(String id) async {
    await FirebaseFirestore.instance
        .collection('prompt_templates')
        .doc(id)
        .delete();
  }

  // 프롬프트 생성 및 실행
  String generatePrompt({
    required PromptTemplate template,
    required Map<String, dynamic> variables,
  }) {
    String result = template.template;

    for (final variable in template.variables) {
      final value = variables[variable]?.toString() ?? '';
      result = result.replaceAll('{$variable}', value);
    }

    return result;
  }

  Future<PromptExecution> executePrompt({
    required String templateId,
    required LLMModel model,
    required Map<String, dynamic> variables,
    Function(String)? onPromptGenerated,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // 템플릿 조회
    final template = await getTemplate(templateId);
    if (template == null) throw Exception('Template not found');

    // 프롬프트 생성
    final finalPrompt = generatePrompt(template: template, variables: variables);
    onPromptGenerated?.call(finalPrompt);

    // 모델 실행 (실제 구현은 Cloud Functions)
    final startTime = DateTime.now();
    final result = await _executeModel(model, finalPrompt);
    final endTime = DateTime.now();

    final execution = PromptExecution(
      id: _generateId(),
      templateId: templateId,
      userId: user.uid,
      model: model,
      variables: variables,
      finalPrompt: finalPrompt,
      response: result.response,
      responseTime: endTime.difference(startTime).inMilliseconds,
      tokenCount: result.tokenCount,
      cost: result.cost,
      userRating: 0.0,
      timestamp: DateTime.now(),
    );

    // 실행 기록 저장
    await FirebaseFirestore.instance
        .collection('prompt_executions')
        .doc(execution.id)
        .set(execution.toMap());

    // 템플릿 사용량 업데이트
    await _updateTemplateUsage(templateId);

    return execution;
  }

  // 실행 기록 관리
  Future<List<PromptExecution>> getExecutions({
    String? userId,
    String? templateId,
    String? modelId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    Query query = FirebaseFirestore.instance.collection('prompt_executions');

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    if (templateId != null) {
      query = query.where('templateId', isEqualTo: templateId);
    }

    if (modelId != null) {
      query = query.where('modelId', isEqualTo: modelId);
    }

    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    query = query.orderBy('timestamp', descending: true).limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => PromptExecution.fromMap(doc.data()))
        .toList();
  }

  Future<void> rateExecution(String executionId, double rating, {String? feedback}) async {
    await FirebaseFirestore.instance
        .collection('prompt_executions')
        .doc(executionId)
        .update({
          'userRating': rating,
          'feedback': feedback,
        });

    // 템플릿 평균 평점 업데이트
    await _updateTemplateRating(executionId, rating);
  }

  // 추천 시스템
  Future<List<PromptTemplate>> getRecommendedTemplates({
    required String userId,
    required PromptCategory category,
    int limit = 5,
  }) async {
    // 사용자 과거 사용 패턴 분석
    final userExecutions = await getExecutions(userId: userId, limit: 50);
    final preferredModels = <String>{};
    final preferredTypes = <PromptTemplateType>{};

    for (final execution in userExecutions) {
      preferredModels.add(execution.model.id);

      final template = await getTemplate(execution.templateId);
      if (template != null) {
        preferredTypes.add(template.type);
      }
    }

    // 추천 점수 계산
    final templates = await getTemplates(category: category, isPublic: true);
    final scoredTemplates = templates.map((template) {
      double score = 0.0;

      // 인기도 점수
      score += template.usageCount * 0.1;
      score += template.averageRating * 2.0;

      // 타입 선호도 점수
      if (preferredTypes.contains(template.type)) {
        score += 1.0;
      }

      return MapEntry(template, score);
    }).toList();

    // 점수순 정렬
    scoredTemplates.sort((a, b) => b.value.compareTo(a.value));

    return scoredTemplates.take(limit).map((e) => e.key).toList();
  }

  // 템플릿 최적화
  Future<String> optimizePrompt({
    required String originalPrompt,
    required LLMModel model,
    required String goal,
  }) async {
    // 프롬프트 최적화를 위한 메타 프롬프트
    final optimizationPrompt = '''
다음 프롬프트를 '$goal' 목적에 맞게 최적화해주세요.

원본 프롬프트:
$originalPrompt

최적화된 프롬프트를 더 명확하고 효과적으로 만들어주세요.
''';

    // 모델 실행 (실제 구현은 Cloud Functions)
    final result = await _executeModel(model, optimizationPrompt);
    return result.response;
  }

  // --- Private Methods ---

  Future<ModelExecutionResult> _executeModel(LLMModel model, String prompt) async {
    // 실제 API 호출 구현 (Cloud Functions)
    // 여기서는 Mock 데이터 반환

    await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(1500)));

    // 토큰 수 계산 (간단한 근사)
    final tokenCount = (prompt.length / 4).ceil() + Random().nextInt(200);

    return ModelExecutionResult(
      response: '[$model.name] 모델의 응답: "$prompt"에 대한 처리 결과입니다. 실제 구현에서는 Cloud Functions를 통해 모델 API를 호출합니다.',
      tokenCount: tokenCount,
      cost: tokenCount * model.costPerToken,
    );
  }

  Future<void> _updateTemplateUsage(String templateId) async {
    await FirebaseFirestore.instance
        .collection('prompt_templates')
        .doc(templateId)
        .update({
          'usageCount': FieldValue.increment(1),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  Future<void> _updateTemplateRating(String executionId, double rating) async {
    final executionDoc = await FirebaseFirestore.instance
        .collection('prompt_executions')
        .doc(executionId)
        .get();

    if (!executionDoc.exists) return;

    final execution = PromptExecution.fromMap(executionDoc.data());

    // 해당 템플릿의 모든 실행 기록 조회
    final executionsSnapshot = await FirebaseFirestore.instance
        .collection('prompt_executions')
        .where('templateId', isEqualTo: execution.templateId)
        .where('userRating', isGreaterThan: 0)
        .get();

    if (executionsSnapshot.docs.isEmpty) return;

    final ratings = executionsSnapshot.docs
        .map((doc) => (doc.data()['userRating'] as num).toDouble())
        .toList();

    final averageRating = ratings.reduce((a, b) => a + b) / ratings.length;

    await FirebaseFirestore.instance
        .collection('prompt_templates')
        .doc(execution.templateId)
        .update({
      'averageRating': averageRating,
    });
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }
}

class ModelExecutionResult {
  final String response;
  final int tokenCount;
  final double cost;

  const ModelExecutionResult({
    required this.response,
    required this.tokenCount,
    required this.cost,
  });
}

// 사전 정의된 템플릿들
class PredefinedTemplates {
  static List<PromptTemplate> get basicTemplates => [
    PromptTemplate(
      id: 'grant_analysis_basic',
      name: '지원사업 기본 분석',
      description: '지원사업 공고문을 기본적으로 분석합니다.',
      category: PromptCategory.grantAnalysis,
      type: PromptTemplateType.basic,
      template: '''다음 지원사업 공고문을 분석해주세요:

제목: {title}
내용: {content}

주요 지원 조건, 지원 대상, 지원 금액 등을 정리해주세요.''',
      variables: ['title', 'content'],
      examples: [
        'title: "스타트업 기술 개발 지원사업", content: "..."',
      ],
      isPublic: true,
      usageCount: 0,
      averageRating: 0.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),

    PromptTemplate(
      id: 'grant_writing_structured',
      name: '지원서 구조화 작성',
      description: '체계적인 구조로 지원서를 작성합니다.',
      category: PromptCategory.grantWriting,
      type: PromptTemplateType.structured,
      template: '''다음 정보를 바탕으로 지원서를 작성해주세요:

사업명: {projectName}
사업 목표: {objectives}
예상 기간: {duration}
필요 자금: {budget}

다음 구조에 맞춰 작성해주세요:
1. 사업 개요
2. 수행 계획
3. 기대효과
4. 예산 계획''',
      variables: ['projectName', 'objectives', 'duration', 'budget'],
      isPublic: true,
      usageCount: 0,
      averageRating: 0.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),

    PromptTemplate(
      id: 'document_review_cot',
      name: '문서 검토 (사고 연쇄)',
      description: '단계별로 문서를 깊이 있게 검토합니다.',
      category: PromptCategory.documentReview,
      type: PromptTemplateType.chainOfThought,
      template: '''다음 문서를 단계별로 검토해주세요:

문서 내용: {content}

단계 1: 문서의 전체적인 구조와 목적 파악
단계 2: 주요 내용 분석
단계 3: 논리적 흐름 검토
단계 4: 개선점 제시

각 단계별로 상세히 분석해주세요.''',
      variables: ['content'],
      isPublic: true,
      usageCount: 0,
      averageRating: 0.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];
}