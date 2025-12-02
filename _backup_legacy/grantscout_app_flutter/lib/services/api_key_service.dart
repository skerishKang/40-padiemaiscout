import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/llm_model.dart';
import '../utils/error_handler.dart';

class ApiKeyService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _keyPrefix = 'api_key_';
  static const String _hashPrefix = 'api_hash_';

  // API 키 저장 (암호화)
  static Future<void> storeApiKey(String provider, String apiKey) async {
    try {
      // API 키 해시 생성 (보안을 위함)
      final hash = sha256.convert(utf8.encode(apiKey)).toString();

      // 안전한 저장소에 암호화된 키 저장
      await _secureStorage.write(
        key: '${_keyPrefix}${provider.toLowerCase()}',
        value: apiKey,
      );

      // 해시는 Firestore에 저장 (중복 체크용)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('api_keys')
            .doc(provider.toLowerCase())
            .set({
          'hash': hash,
          'provider': provider,
          'lastUsed': DateTime.now().toIso8601String(),
          'isActive': true,
        });
      }
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'store_api_key'});
    }
  }

  // API 키 조회
  static Future<String?> getApiKey(String provider) async {
    try {
      return await _secureStorage.read(
        key: '${_keyPrefix}${provider.toLowerCase()}',
      );
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'get_api_key'});
    }
  }

  // API 키 목록 조회
  static Future<Map<String, String>> getAllApiKeys() async {
    try {
      final Map<String, String> apiKeys = {};

      // 지원하는 모든 제공사에 대해 키 조회
      for (final model in LLMModel.getAllModels()) {
        final provider = model.provider.name.toLowerCase();
        final apiKey = await getApiKey(provider);
        if (apiKey != null && apiKey.isNotEmpty) {
          apiKeys[provider] = apiKey;
        }
      }

      return apiKeys;
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'get_all_api_keys'});
    }
  }

  // API 키 삭제
  static Future<void> deleteApiKey(String provider) async {
    try {
      await _secureStorage.delete(
        key: '${_keyPrefix}${provider.toLowerCase()}',
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('api_keys')
            .doc(provider.toLowerCase())
            .update({'isActive': false});
      }
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'delete_api_key'});
    }
  }

  // API 키 유효성 검증
  static Future<bool> validateApiKey(String provider, String apiKey) async {
    try {
      // TODO: 각 제공사별 실제 API 호출로 유효성 검증
      switch (provider.toLowerCase()) {
        case 'gemini':
          return await _validateGeminiKey(apiKey);
        case 'openai':
          return await _validateOpenAIKey(apiKey);
        case 'claude':
          return await _validateClaudeKey(apiKey);
        case 'clova':
          return await _validateClovaKey(apiKey);
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Gemini API 키 검증
  static Future<bool> _validateGeminiKey(String apiKey) async {
    try {
      // TODO: 실제 Gemini API 호출 구현
      // 지금은 더미 구현
      await Future.delayed(const Duration(seconds: 1));
      return apiKey.isNotEmpty && apiKey.startsWith('AIza');
    } catch (e) {
      return false;
    }
  }

  // OpenAI API 키 검증
  static Future<bool> _validateOpenAIKey(String apiKey) async {
    try {
      // TODO: 실제 OpenAI API 호출 구현
      await Future.delayed(const Duration(seconds: 1));
      return apiKey.isNotEmpty && apiKey.startsWith('sk-');
    } catch (e) {
      return false;
    }
  }

  // Claude API 키 검증
  static Future<bool> _validateClaudeKey(String apiKey) async {
    try {
      // TODO: 실제 Claude API 호출 구현
      await Future.delayed(const Duration(seconds: 1));
      return apiKey.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // CLOVA API 키 검증
  static Future<bool> _validateClovaKey(String apiKey) async {
    try {
      // TODO: 실제 CLOVA API 호출 구현
      await Future.delayed(const Duration(seconds: 1));
      return apiKey.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // API 키 마지막 사용 시간 업데이트
  static Future<void> updateLastUsed(String provider) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('api_keys')
            .doc(provider.toLowerCase())
            .update({
          'lastUsed': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // 에러를 무시 (필수 기능이 아님)
    }
  }

  // 활성 API 키 통계
  static Future<Map<String, dynamic>> getApiKeyStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('api_keys')
          .where('isActive', isEqualTo: true)
          .get();

      final Map<String, int> providerCounts = {};
      DateTime? lastUsed;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final provider = data['provider'] as String;
        providerCounts[provider] = (providerCounts[provider] ?? 0) + 1;

        final used = DateTime.tryParse(data['lastUsed'] as String? ?? '');
        if (used != null && (lastUsed == null || used.isAfter(lastUsed))) {
          lastUsed = used;
        }
      }

      return {
        'totalKeys': snapshot.docs.length,
        'providerCounts': providerCounts,
        'lastUsed': lastUsed?.toIso8601String(),
        'lastUsedDays': lastUsed != null
            ? DateTime.now().difference(lastUsed).inDays
            : null,
      };
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'get_api_stats'});
    }
  }

  // API 키 백업 (Firestore에 암호화된 키 저장)
  static Future<void> backupApiKeys() async {
    try {
      final apiKeys = await getAllApiKeys();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && apiKeys.isNotEmpty) {
        // 각 키를 개별적으로 암호화하여 저장
        for (final entry in apiKeys.entries) {
          final provider = entry.key;
          final apiKey = entry.value;
          final hash = sha256.convert(utf8.encode(apiKey)).toString();

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('api_key_backups')
              .doc(provider)
              .set({
            'hash': hash,
            'provider': provider,
            'backedUpAt': DateTime.now().toIso8601String(),
            'isActive': true,
          });
        }
      }
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'backup_api_keys'});
    }
  }

  // API 키 복원
  static Future<void> restoreApiKeys() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('api_key_backups')
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final provider = data['provider'] as String;

        // 복원은 사용자 확인이 필요하므로 여기서는 기록만 남김
        // 실제 복원은 UI를 통해 진행
      }
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'restore_api_keys'});
    }
  }

  // 모든 API 키 삭제 (로그아웃 시)
  static Future<void> clearAllApiKeys() async {
    try {
      for (final model in LLMModel.getAllModels()) {
        final provider = model.provider.name.toLowerCase();
        await deleteApiKey(provider);
      }
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'clear_all_api_keys'});
    }
  }
}