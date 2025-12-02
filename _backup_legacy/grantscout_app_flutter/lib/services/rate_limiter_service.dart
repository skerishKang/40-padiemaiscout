import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/llm_model.dart';

enum RateLimitType {
  requestsPerMinute,
  requestsPerHour,
  requestsPerDay,
  tokensPerMinute,
  tokensPerHour,
  costPerDay,
}

class RateLimitRule {
  final String id;
  final String modelId;
  final RateLimitType type;
  final double limit;
  final int windowMinutes;
  final String? userId;
  final bool isGlobal;
  final DateTime createdAt;
  final bool isActive;

  const RateLimitRule({
    required this.id,
    required this.modelId,
    required this.type,
    required this.limit,
    required this.windowMinutes,
    this.userId,
    this.isGlobal = false,
    required this.createdAt,
    this.isActive = true,
  });

  factory RateLimitRule.fromMap(Map<String, dynamic> map) {
    return RateLimitRule(
      id: map['id'] ?? '',
      modelId: map['modelId'] ?? '',
      type: RateLimitType.values.firstWhere((t) => t.name == map['type']),
      limit: (map['limit'] as num).toDouble(),
      windowMinutes: map['windowMinutes'] ?? 60,
      userId: map['userId'],
      isGlobal: map['isGlobal'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'modelId': modelId,
      'type': type.name,
      'limit': limit,
      'windowMinutes': windowMinutes,
      'userId': userId,
      'isGlobal': isGlobal,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
}

class UsageRecord {
  final String id;
  final String modelId;
  final String userId;
  final RateLimitType type;
  final double amount;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const UsageRecord({
    required this.id,
    required this.modelId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.timestamp,
    this.metadata = const {},
  });

  factory UsageRecord.fromMap(Map<String, dynamic> map) {
    return UsageRecord(
      id: map['id'] ?? '',
      modelId: map['modelId'] ?? '',
      userId: map['userId'] ?? '',
      type: RateLimitType.values.firstWhere((t) => t.name == map['type']),
      amount: (map['amount'] as num).toDouble(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'modelId': modelId,
      'userId': userId,
      'type': type.name,
      'amount': amount,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }
}

class RateLimitResult {
  final bool allowed;
  final String? reason;
  final int remainingQuota;
  final DateTime resetTime;
  final RateLimitType limitType;

  const RateLimitResult({
    required this.allowed,
    this.reason,
    required this.remainingQuota,
    required this.resetTime,
    required this.limitType,
  });
}

class RateLimiterService {
  static final RateLimiterService _instance = RateLimiterService._internal();
  factory RateLimiterService() => _instance;
  RateLimiterService._internal();

  final Map<String, List<UsageRecord>> _usageCache = {};
  final Map<String, List<RateLimitRule>> _rulesCache = {};
  Timer? _cleanupTimer;

  // 기본 제한 규칙
  static const Map<RateLimitType, Map<String, double>> defaultLimits = {
    RateLimitType.requestsPerMinute: {
      'free': 10,
      'basic': 30,
      'pro': 100,
    },
    RateLimitType.requestsPerHour: {
      'free': 100,
      'basic': 500,
      'pro': 2000,
    },
    RateLimitType.requestsPerDay: {
      'free': 1000,
      'basic': 5000,
      'pro': 20000,
    },
    RateLimitType.tokensPerMinute: {
      'free': 10000,
      'basic': 50000,
      'pro': 200000,
    },
    RateLimitType.costPerDay: {
      'free': 1.0,
      'basic': 10.0,
      'pro': 100.0,
    },
  };

  void initialize() {
    // 5분마다 캐시 정리
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) => _cleanupCache());
    _initializeDefaultRules();
  }

  void dispose() {
    _cleanupTimer?.cancel();
  }

  // API 요청 전 속도 제한 확인
  Future<RateLimitResult> checkRateLimit({
    required LLMModel model,
    required String userId,
    String? userTier,
    Map<String, dynamic>? metadata,
  }) async {
    final tier = userTier ?? 'free';
    final currentUsage = await _getCurrentUsage(model.id, userId);
    final applicableRules = await _getApplicableRules(model.id, userId, tier);

    for (final rule in applicableRules) {
      final windowUsage = _getUsageInWindow(currentUsage, rule.type, rule.windowMinutes);

      if (windowUsage >= rule.limit) {
        return RateLimitResult(
          allowed: false,
          reason: _getLimitExceededMessage(rule.type, rule.limit, rule.windowMinutes),
          remainingQuota: 0,
          resetTime: _calculateResetTime(rule.windowMinutes),
          limitType: rule.type,
        );
      }
    }

    // 가장 제한적인 규칙 기준으로 남은 용량 계산
    final mostRestrictiveRule = _getMostRestrictiveRule(applicableRules, currentUsage);
    final remaining = (mostRestrictiveRule.limit -
        _getUsageInWindow(currentUsage, mostRestrictiveRule.type, mostRestrictiveRule.windowMinutes))
        .toInt();

    return RateLimitResult(
      allowed: true,
      remainingQuota: remaining,
      resetTime: _calculateResetTime(mostRestrictiveRule.windowMinutes),
      limitType: mostRestrictiveRule.type,
    );
  }

  // API 요청 사용량 기록
  Future<void> recordUsage({
    required LLMModel model,
    required String userId,
    required int requestCount,
    required int tokenCount,
    required double cost,
    Map<String, dynamic>? metadata,
  }) async {
    final timestamp = DateTime.now();

    // 요청 수 기록
    await _recordUsageEntry(UsageRecord(
      id: _generateId(),
      modelId: model.id,
      userId: userId,
      type: RateLimitType.requestsPerMinute,
      amount: requestCount.toDouble(),
      timestamp: timestamp,
      metadata: metadata ?? {},
    ));

    // 토큰 수 기록
    await _recordUsageEntry(UsageRecord(
      id: _generateId(),
      modelId: model.id,
      userId: userId,
      type: RateLimitType.tokensPerMinute,
      amount: tokenCount.toDouble(),
      timestamp: timestamp,
      metadata: metadata ?? {},
    ));

    // 비용 기록
    await _recordUsageEntry(UsageRecord(
      id: _generateId(),
      modelId: model.id,
      userId: userId,
      type: RateLimitType.costPerDay,
      amount: cost,
      timestamp: timestamp,
      metadata: metadata ?? {},
    ));
  }

  // 사용량 통계 조회
  Future<UsageStatistics> getUsageStatistics({
    required String userId,
    required String modelId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('usage_records')
        .where('userId', isEqualTo: userId)
        .where('modelId', isEqualTo: modelId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    final records = snapshot.docs
        .map((doc) => UsageRecord.fromMap(doc.data()))
        .toList();

    return UsageStatistics.fromRecords(records);
  }

  // 제한 규칙 관리
  Future<void> createRule(RateLimitRule rule) async {
    await FirebaseFirestore.instance
        .collection('rate_limit_rules')
        .doc(rule.id)
        .set(rule.toMap());

    // 캐시 무효화
    _rulesCache.clear();
  }

  Future<void> updateRule(String ruleId, Map<String, dynamic> updates) async {
    await FirebaseFirestore.instance
        .collection('rate_limit_rules')
        .doc(ruleId)
        .update(updates);

    // 캐시 무효화
    _rulesCache.clear();
  }

  Future<void> deleteRule(String ruleId) async {
    await FirebaseFirestore.instance
        .collection('rate_limit_rules')
        .doc(ruleId)
        .delete();

    // 캐시 무효화
    _rulesCache.clear();
  }

  Future<List<RateLimitRule>> getAllRules() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('rate_limit_rules')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => RateLimitRule.fromMap(doc.data()))
        .toList();
  }

  // --- Private Methods ---

  Future<void> _initializeDefaultRules() async {
    final existingRules = await getAllRules();

    if (existingRules.isEmpty) {
      // 기본 규칙 생성
      for (final model in LLMModel.getAllModels()) {
        for (final tier in ['free', 'basic', 'pro']) {
          for (final entry in defaultLimits.entries) {
            final rule = RateLimitRule(
              id: _generateId(),
              modelId: model.id,
              type: entry.key,
              limit: entry.value[tier]!,
              windowMinutes: _getWindowMinutes(entry.key),
              isGlobal: true,
              createdAt: DateTime.now(),
            );

            await createRule(rule);
          }
        }
      }
    }
  }

  int _getWindowMinutes(RateLimitType type) {
    switch (type) {
      case RateLimitType.requestsPerMinute:
      case RateLimitType.tokensPerMinute:
        return 1;
      case RateLimitType.requestsPerHour:
        return 60;
      case RateLimitType.requestsPerDay:
      case RateLimitType.costPerDay:
        return 1440; // 24시간
      case RateLimitType.tokensPerHour:
        return 60;
    }
  }

  Future<List<UsageRecord>> _getCurrentUsage(String modelId, String userId) async {
    final cacheKey = '${modelId}_${userId}';

    if (_usageCache.containsKey(cacheKey)) {
      return _usageCache[cacheKey]!;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('usage_records')
        .where('modelId', isEqualTo: modelId)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1000)
        .get();

    final records = snapshot.docs
        .map((doc) => UsageRecord.fromMap(doc.data()))
        .toList();

    _usageCache[cacheKey] = records;
    return records;
  }

  Future<List<RateLimitRule>> _getApplicableRules(String modelId, String userId, String tier) async {
    final cacheKey = '${modelId}_${userId}_${tier}';

    if (_rulesCache.containsKey(cacheKey)) {
      return _rulesCache[cacheKey]!;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('rate_limit_rules')
        .where('modelId', isEqualTo: modelId)
        .where('isActive', isEqualTo: true)
        .get();

    final rules = snapshot.docs
        .map((doc) => RateLimitRule.fromMap(doc.data()))
        .where((rule) =>
            rule.isGlobal ||
            rule.userId == userId ||
            _isTierRule(rule, tier))
        .toList();

    _rulesCache[cacheKey] = rules;
    return rules;
  }

  bool _isTierRule(RateLimitRule rule, String tier) {
    // 규칙 ID나 메타데이터에서 티어 정보 확인
    return rule.id.contains(tier) ||
           (rule.metadata['tier'] as String?) == tier;
  }

  double _getUsageInWindow(List<UsageRecord> records, RateLimitType type, int windowMinutes) {
    final cutoff = DateTime.now().subtract(Duration(minutes: windowMinutes));

    return records
        .where((record) =>
            record.type == type &&
            record.timestamp.isAfter(cutoff))
        .fold(0.0, (sum, record) => sum + record.amount);
  }

  RateLimitRule _getMostRestrictiveRule(List<RateLimitRule> rules, List<UsageRecord> currentUsage) {
    return rules.reduce((a, b) {
      final aUsage = _getUsageInWindow(currentUsage, a.type, a.windowMinutes);
      final bUsage = _getUsageInWindow(currentUsage, b.type, b.windowMinutes);

      final aRemaining = a.limit - aUsage;
      final bRemaining = b.limit - bUsage;

      return aRemaining < bRemaining ? a : b;
    });
  }

  String _getLimitExceededMessage(RateLimitType type, double limit, int windowMinutes) {
    switch (type) {
      case RateLimitType.requestsPerMinute:
        return '분당 $limit 회 요청 제한을 초과했습니다.';
      case RateLimitType.requestsPerHour:
        return '시간당 $limit 회 요청 제한을 초과했습니다.';
      case RateLimitType.requestsPerDay:
        return '일일 $limit 회 요청 제한을 초과했습니다.';
      case RateLimitType.tokensPerMinute:
        return '분당 ${limit.toInt()} 토큰 제한을 초과했습니다.';
      case RateLimitType.tokensPerHour:
        return '시간당 ${limit.toInt()} 토큰 제한을 초과했습니다.';
      case RateLimitType.costPerDay:
        return '일일 \$${limit.toStringAsFixed(2)} 비용 제한을 초과했습니다.';
    }
  }

  DateTime _calculateResetTime(int windowMinutes) {
    return DateTime.now().add(Duration(minutes: windowMinutes));
  }

  Future<void> _recordUsageEntry(UsageRecord record) async {
    await FirebaseFirestore.instance
        .collection('usage_records')
        .doc(record.id)
        .set(record.toMap());

    // 캐시에 추가
    final cacheKey = '${record.modelId}_${record.userId}';
    if (_usageCache.containsKey(cacheKey)) {
      _usageCache[cacheKey]!.insert(0, record);

      // 캐시 크기 제한
      if (_usageCache[cacheKey]!.length > 1000) {
        _usageCache[cacheKey] = _usageCache[cacheKey]!.take(1000).toList();
      }
    }
  }

  void _cleanupCache() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));

    _usageCache.removeWhere((key, records) {
      records.removeWhere((record) => record.timestamp.isBefore(cutoff));
      return records.isEmpty;
    });

    _rulesCache.clear();
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }
}

class UsageStatistics {
  final int totalRequests;
  final int totalTokens;
  final double totalCost;
  final Map<RateLimitType, double> usageByType;
  final Map<String, int> requestsByHour;
  final double averageResponseTime;
  final DateTime lastActivity;

  const UsageStatistics({
    required this.totalRequests,
    required this.totalTokens,
    required this.totalCost,
    required this.usageByType,
    required this.requestsByHour,
    required this.averageResponseTime,
    required this.lastActivity,
  });

  factory UsageStatistics.fromRecords(List<UsageRecord> records) {
    int totalRequests = 0;
    int totalTokens = 0;
    double totalCost = 0.0;
    final usageByType = <RateLimitType, double>{};
    final requestsByHour = <String, int>{};
    List<double> responseTimes = [];

    DateTime? lastActivity;

    for (final record in records) {
      switch (record.type) {
        case RateLimitType.requestsPerMinute:
        case RateLimitType.requestsPerHour:
        case RateLimitType.requestsPerDay:
          totalRequests += record.amount.toInt();
          break;
        case RateLimitType.tokensPerMinute:
        case RateLimitType.tokensPerHour:
          totalTokens += record.amount.toInt();
          break;
        case RateLimitType.costPerDay:
          totalCost += record.amount;
          break;
      }

      usageByType[record.type] = (usageByType[record.type] ?? 0) + record.amount;

      final hour = record.timestamp.toString().substring(0, 13);
      requestsByHour[hour] = (requestsByHour[hour] ?? 0) + 1;

      if (record.metadata['responseTime'] != null) {
        responseTimes.add((record.metadata['responseTime'] as num).toDouble());
      }

      if (lastActivity == null || record.timestamp.isAfter(lastActivity)) {
        lastActivity = record.timestamp;
      }
    }

    final averageResponseTime = responseTimes.isNotEmpty
        ? responseTimes.reduce((a, b) => a + b) / responseTimes.length
        : 0.0;

    return UsageStatistics(
      totalRequests: totalRequests,
      totalTokens: totalTokens,
      totalCost: totalCost,
      usageByType: usageByType,
      requestsByHour: requestsByHour,
      averageResponseTime: averageResponseTime,
      lastActivity: lastActivity ?? DateTime.now(),
    );
  }
}