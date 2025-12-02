import 'package:flutter/material.dart';
import '../services/cache_service.dart';
import '../models/user_profile.dart';
import '../models/uploaded_file.dart';

class CacheProvider extends ChangeNotifier {
  bool _isInitialized = false;
  int _cacheSize = 0;
  DateTime? _lastCleanup;

  bool get isInitialized => _isInitialized;
  int get cacheSize => _cacheSize;
  DateTime? get lastCleanup => _lastCleanup;

  Future<void> initialize() async {
    try {
      await CacheService.initialize();
      _isInitialized = true;
      _updateCacheSize();
      
      // 초기화 시 만료된 캐시 정리
      await cleanExpiredCache();
      
      notifyListeners();
    } catch (e) {
      debugPrint('캐시 프로바이더 초기화 실패: $e');
    }
  }

  // 사용자 프로필 캐싱
  Future<bool> cacheUserProfile(String userId, UserProfile profile) async {
    final key = CacheKeys.userProfileKey(userId);
    final result = await CacheService.set(key, profile.toMap(), expiration: Duration(hours: 12));
    if (result) {
      _updateCacheSize();
      notifyListeners();
    }
    return result;
  }

  Future<UserProfile?> getCachedUserProfile(String userId) async {
    final key = CacheKeys.userProfileKey(userId);
    final data = await CacheService.get<Map<String, dynamic>>(key);
    return data != null ? UserProfile.fromMap(data) : null;
  }

  // API 키 상태 캐싱
  Future<bool> cacheApiKeyStatus(Map<String, dynamic> status) async {
    final result = await CacheService.set(
      CacheKeys.apiKeyStatus, 
      status, 
      expiration: Duration(minutes: 30),
    );
    if (result) {
      _updateCacheSize();
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>?> getCachedApiKeyStatus() async {
    return await CacheService.get<Map<String, dynamic>>(CacheKeys.apiKeyStatus);
  }

  // 업로드된 파일 목록 캐싱
  Future<bool> cacheUploadedFiles(String userId, List<UploadedFile> files) async {
    final key = CacheKeys.uploadedFilesKey(userId);
    final data = files.map((file) => file.toMap()).toList();
    final result = await CacheService.set(key, data, expiration: Duration(minutes: 15));
    if (result) {
      _updateCacheSize();
      notifyListeners();
    }
    return result;
  }

  Future<List<UploadedFile>?> getCachedUploadedFiles(String userId) async {
    final key = CacheKeys.uploadedFilesKey(userId);
    final data = await CacheService.get<List<dynamic>>(key);
    if (data != null) {
      try {
        return data.map((item) => UploadedFile.fromFirestore(
          // Mock document snapshot for deserialization
          MockDocumentSnapshot(item['id'], item)
        )).toList();
      } catch (e) {
        debugPrint('캐시된 파일 목록 파싱 실패: $e');
        await CacheService.remove(key);
      }
    }
    return null;
  }

  // 분석 결과 캐싱
  Future<bool> cacheAnalysisResult(String fileId, Map<String, dynamic> result) async {
    final key = CacheKeys.analysisResultKey(fileId);
    final cached = await CacheService.set(key, result, expiration: Duration(days: 7));
    if (cached) {
      _updateCacheSize();
      notifyListeners();
    }
    return cached;
  }

  Future<Map<String, dynamic>?> getCachedAnalysisResult(String fileId) async {
    final key = CacheKeys.analysisResultKey(fileId);
    return await CacheService.get<Map<String, dynamic>>(key);
  }

  // 적합성 분석 결과 캐싱
  Future<bool> cacheSuitabilityResult(
    String fileId, 
    Map<String, dynamic> result,
  ) async {
    final key = CacheKeys.suitabilityResultKey(fileId);
    final cached = await CacheService.set(key, result, expiration: Duration(days: 3));
    if (cached) {
      _updateCacheSize();
      notifyListeners();
    }
    return cached;
  }

  Future<Map<String, dynamic>?> getCachedSuitabilityResult(String fileId) async {
    final key = CacheKeys.suitabilityResultKey(fileId);
    return await CacheService.get<Map<String, dynamic>>(key);
  }

  // 특정 사용자의 모든 캐시 제거
  Future<bool> clearUserCache(String userId) async {
    final result = await CacheService.removePattern(userId);
    if (result) {
      _updateCacheSize();
      notifyListeners();
    }
    return result;
  }

  // 만료된 캐시 정리
  Future<int> cleanExpiredCache() async {
    final removedCount = await CacheService.cleanExpiredCache();
    if (removedCount > 0) {
      _lastCleanup = DateTime.now();
      _updateCacheSize();
      notifyListeners();
    }
    return removedCount;
  }

  // 전체 캐시 제거
  Future<bool> clearAllCache() async {
    final result = await CacheService.clear();
    if (result) {
      _cacheSize = 0;
      notifyListeners();
    }
    return result;
  }

  // 캐시 크기 업데이트
  void _updateCacheSize() {
    _cacheSize = CacheService.getCacheSize();
  }

  // 캐시 통계 정보 제공
  Map<String, dynamic> getCacheStats() {
    return {
      'size': _cacheSize,
      'isInitialized': _isInitialized,
      'lastCleanup': _lastCleanup?.toIso8601String(),
    };
  }

  // 자동 캐시 정리 스케줄링 (앱 시작 시 한 번)
  Future<void> scheduleCleanup() async {
    // 마지막 정리 후 24시간이 지났으면 정리 실행
    if (_lastCleanup == null || 
        DateTime.now().difference(_lastCleanup!).inHours >= 24) {
      await cleanExpiredCache();
    }
  }
}

// Mock 클래스 (실제 구현에서는 cloud_firestore의 DocumentSnapshot 사용)
class MockDocumentSnapshot {
  final String id;
  final Map<String, dynamic> _data;

  MockDocumentSnapshot(this.id, this._data);

  Map<String, dynamic> data() => _data;
}