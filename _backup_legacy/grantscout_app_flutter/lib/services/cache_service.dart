import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class CacheService {
  static SharedPreferences? _prefs;
  static const String _keyPrefix = 'grantscout_cache_';
  static const Duration _defaultExpiration = Duration(hours: 24);

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _preferences {
    if (_prefs == null) {
      throw StateError('CacheService가 초기화되지 않았습니다. initialize()를 먼저 호출하세요.');
    }
    return _prefs!;
  }

  // 캐시에 데이터 저장
  static Future<bool> set<T>(
    String key,
    T value, {
    Duration? expiration,
  }) async {
    try {
      final cacheKey = _keyPrefix + key;
      final expirationTime = DateTime.now().add(expiration ?? _defaultExpiration);
      
      final cacheData = {
        'value': _serializeValue(value),
        'expiration': expirationTime.millisecondsSinceEpoch,
        'type': T.toString(),
      };

      final jsonString = jsonEncode(cacheData);
      final result = await _preferences.setString(cacheKey, jsonString);
      
      if (result) {
        debugPrint('캐시 저장 성공: $key');
      }
      
      return result;
    } catch (e) {
      debugPrint('캐시 저장 실패: $key, 오류: $e');
      return false;
    }
  }

  // 캐시에서 데이터 조회
  static Future<T?> get<T>(String key) async {
    try {
      final cacheKey = _keyPrefix + key;
      final jsonString = _preferences.getString(cacheKey);
      
      if (jsonString == null) {
        debugPrint('캐시 없음: $key');
        return null;
      }

      final cacheData = jsonDecode(jsonString) as Map<String, dynamic>;
      final expirationTime = DateTime.fromMillisecondsSinceEpoch(cacheData['expiration']);
      
      // 만료 확인
      if (DateTime.now().isAfter(expirationTime)) {
        debugPrint('캐시 만료: $key');
        await remove(key);
        return null;
      }

      final value = _deserializeValue<T>(cacheData['value'], cacheData['type']);
      debugPrint('캐시 조회 성공: $key');
      return value;
    } catch (e) {
      debugPrint('캐시 조회 실패: $key, 오류: $e');
      return null;
    }
  }

  // 캐시에서 데이터 제거
  static Future<bool> remove(String key) async {
    try {
      final cacheKey = _keyPrefix + key;
      final result = await _preferences.remove(cacheKey);
      
      if (result) {
        debugPrint('캐시 제거 성공: $key');
      }
      
      return result;
    } catch (e) {
      debugPrint('캐시 제거 실패: $key, 오류: $e');
      return false;
    }
  }

  // 특정 패턴의 캐시 제거
  static Future<bool> removePattern(String pattern) async {
    try {
      final keys = _preferences.getKeys();
      final targetKeys = keys.where((key) => 
        key.startsWith(_keyPrefix) && 
        key.substring(_keyPrefix.length).contains(pattern)
      ).toList();

      for (final key in targetKeys) {
        await _preferences.remove(key);
      }

      debugPrint('패턴 캐시 제거 성공: $pattern (${targetKeys.length}개)');
      return true;
    } catch (e) {
      debugPrint('패턴 캐시 제거 실패: $pattern, 오류: $e');
      return false;
    }
  }

  // 모든 캐시 제거
  static Future<bool> clear() async {
    try {
      final keys = _preferences.getKeys();
      final cacheKeys = keys.where((key) => key.startsWith(_keyPrefix)).toList();

      for (final key in cacheKeys) {
        await _preferences.remove(key);
      }

      debugPrint('전체 캐시 제거 성공 (${cacheKeys.length}개)');
      return true;
    } catch (e) {
      debugPrint('전체 캐시 제거 실패: $e');
      return false;
    }
  }

  // 캐시 크기 확인
  static int getCacheSize() {
    final keys = _preferences.getKeys();
    return keys.where((key) => key.startsWith(_keyPrefix)).length;
  }

  // 만료된 캐시 정리
  static Future<int> cleanExpiredCache() async {
    try {
      final keys = _preferences.getKeys();
      final cacheKeys = keys.where((key) => key.startsWith(_keyPrefix)).toList();
      int removedCount = 0;

      for (final cacheKey in cacheKeys) {
        final jsonString = _preferences.getString(cacheKey);
        if (jsonString == null) continue;

        try {
          final cacheData = jsonDecode(jsonString) as Map<String, dynamic>;
          final expirationTime = DateTime.fromMillisecondsSinceEpoch(cacheData['expiration']);
          
          if (DateTime.now().isAfter(expirationTime)) {
            await _preferences.remove(cacheKey);
            removedCount++;
          }
        } catch (e) {
          // 손상된 캐시 데이터 제거
          await _preferences.remove(cacheKey);
          removedCount++;
        }
      }

      debugPrint('만료된 캐시 정리 완료: ${removedCount}개');
      return removedCount;
    } catch (e) {
      debugPrint('캐시 정리 실패: $e');
      return 0;
    }
  }

  // 캐시 존재 여부 확인
  static bool contains(String key) {
    final cacheKey = _keyPrefix + key;
    return _preferences.containsKey(cacheKey);
  }

  // 값 직렬화
  static dynamic _serializeValue<T>(T value) {
    if (value is String || value is int || value is double || value is bool) {
      return value;
    } else if (value is List || value is Map) {
      return value;
    } else {
      return value.toString();
    }
  }

  // 값 역직렬화
  static T? _deserializeValue<T>(dynamic value, String type) {
    try {
      if (T == String) {
        return value.toString() as T;
      } else if (T == int) {
        return (value is int ? value : int.parse(value.toString())) as T;
      } else if (T == double) {
        return (value is double ? value : double.parse(value.toString())) as T;
      } else if (T == bool) {
        return (value is bool ? value : value.toString().toLowerCase() == 'true') as T;
      } else if (T == List<String>) {
        return List<String>.from(value as List) as T;
      } else if (T == Map<String, dynamic>) {
        return Map<String, dynamic>.from(value as Map) as T;
      } else {
        return value as T;
      }
    } catch (e) {
      debugPrint('값 역직렬화 실패: $e');
      return null;
    }
  }
}

// 캐시 키 상수들
class CacheKeys {
  static const String userProfile = 'user_profile';
  static const String apiKeyStatus = 'api_key_status';
  static const String uploadedFiles = 'uploaded_files';
  static const String analysisResults = 'analysis_results';
  static const String suitabilityResults = 'suitability_results';
  
  // 동적 키 생성 헬퍼
  static String userProfileKey(String userId) => '${userProfile}_$userId';
  static String uploadedFilesKey(String userId) => '${uploadedFiles}_$userId';
  static String analysisResultKey(String fileId) => '${analysisResults}_$fileId';
  static String suitabilityResultKey(String fileId) => '${suitabilityResults}_$fileId';
}