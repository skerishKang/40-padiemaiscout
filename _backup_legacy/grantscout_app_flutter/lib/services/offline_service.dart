import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/error_handler.dart';
import '../utils/performance_monitor.dart';

class OfflineService {
  static const String _offlineDataPrefix = 'offline_';
  static const String _syncQueuePrefix = 'sync_queue_';
  static Directory? _offlineDir;

  static Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _offlineDir = Directory('${appDir.path}/offline_data');
      if (!await _offlineDir!.exists()) {
        await _offlineDir!.create(recursive: true);
      }
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'offline_init'});
    }
  }

  // 오프라인 데이터 저장
  static Future<void> saveOfflineData(String key, Map<String, dynamic> data) async {
    try {
      PerformanceMonitor.startMeasurement('offline_save');

      if (_offlineDir == null) {
        await initialize();
      }

      final file = File('${_offlineDir!.path}/$_offlineDataPrefix$key.json');
      await file.writeAsString(json.encode(data));

      PerformanceMonitor.endMeasurement('offline_save');
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'save_offline_data'});
    }
  }

  // 오프라인 데이터 조회
  static Future<Map<String, dynamic>?> getOfflineData(String key) async {
    try {
      PerformanceMonitor.startMeasurement('offline_read');

      if (_offlineDir == null) {
        await initialize();
      }

      final file = File('${_offlineDir!.path}/$_offlineDataPrefix$key.json');
      if (!await file.exists()) {
        PerformanceMonitor.endMeasurement('offline_read');
        return null;
      }

      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;

      PerformanceMonitor.endMeasurement('offline_read');
      return data;
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'get_offline_data'});
    }
  }

  // 오프라인 데이터 삭제
  static Future<void> deleteOfflineData(String key) async {
    try {
      if (_offlineDir == null) {
        await initialize();
      }

      final file = File('${_offlineDir!.path}/$_offlineDataPrefix$key.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'delete_offline_data'});
    }
  }

  // 모든 오프라인 데이터 삭제
  static Future<void> clearAllOfflineData() async {
    try {
      if (_offlineDir == null) {
        await initialize();
      }

      if (await _offlineDir!.exists()) {
        await _offlineDir!.delete(recursive: true);
        await _offlineDir!.create();
      }
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'clear_offline_data'});
    }
  }

  // 동기화 큐에 작업 추가
  static Future<void> addToSyncQueue(Map<String, dynamic> operation) async {
    try {
      if (_offlineDir == null) {
        await initialize();
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${_offlineDir!.path}/$_syncQueuePrefix$timestamp.json');

      final queueItem = {
        ...operation,
        'timestamp': timestamp,
        'id': timestamp.toString(),
        'status': 'pending',
      };

      await file.writeAsString(json.encode(queueItem));
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'add_to_sync_queue'});
    }
  }

  // 동기화 큐 조회
  static Future<List<Map<String, dynamic>>> getSyncQueue() async {
    try {
      if (_offlineDir == null) {
        await initialize();
      }

      final files = await _offlineDir!
          .list()
          .where((entity) => entity.path.contains(_syncQueuePrefix))
          .cast<File>()
          .toList();

      final queue = <Map<String, dynamic>>[];

      for (final file in files) {
        try {
          final content = await file.readAsString();
          final item = json.decode(content) as Map<String, dynamic>;
          queue.add(item);
        } catch (e) {
          // 손상된 파일은 건너뛰기
          await file.delete();
        }
      }

      // 타임스탬프로 정렬
      queue.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));

      return queue;
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'get_sync_queue'});
    }
  }

  // 동기화 큐에서 작업 제거
  static Future<void> removeFromSyncQueue(String id) async {
    try {
      if (_offlineDir == null) {
        await initialize();
      }

      final files = await _offlineDir!
          .list()
          .where((entity) => entity.path.contains(_syncQueuePrefix) && entity.path.contains(id))
          .cast<File>()
          .toList();

      for (final file in files) {
        await file.delete();
      }
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'remove_from_sync_queue'});
    }
  }

  // 오프라인 상태에서 데이터 동기화
  static Future<void> syncOfflineData() async {
    try {
      PerformanceMonitor.startMeasurement('offline_sync');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final syncQueue = await getSyncQueue();

      for (final operation in syncQueue) {
        try {
          await _processSyncOperation(operation, user.uid);
          await removeFromSyncQueue(operation['id'] as String);
        } catch (e) {
          // 개별 작업 실패 시 계속 진행
          ErrorHandler.logError(ErrorHandler.handleError(e));
        }
      }

      PerformanceMonitor.endMeasurement('offline_sync');
    } catch (e) {
      throw ErrorHandler.handleError(e, context: {'action': 'sync_offline_data'});
    }
  }

  // 동기화 작업 처리
  static Future<void> _processSyncOperation(Map<String, dynamic> operation, String userId) async {
    final type = operation['type'] as String;
    final collection = operation['collection'] as String;
    final data = operation['data'] as Map<String, dynamic>;
    final documentId = operation['documentId'] as String?;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(collection);

    switch (type) {
      case 'create':
        await docRef.add(data);
        break;
      case 'update':
        if (documentId != null) {
          await docRef.doc(documentId).update(data);
        }
        break;
      case 'delete':
        if (documentId != null) {
          await docRef.doc(documentId).delete();
        }
        break;
    }
  }

  // 파일 분석 결과 오프라인 저장
  static Future<void> saveAnalysisResult(String fileId, Map<String, dynamic> result) async {
    await saveOfflineData('analysis_$fileId', {
      'fileId': fileId,
      'result': result,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': false,
    });
  }

  // 오프라인 분석 결과 조회
  static Future<Map<String, dynamic>?> getAnalysisResult(String fileId) async {
    final data = await getOfflineData('analysis_$fileId');
    return data?['result'] as Map<String, dynamic>?;
  }

  // 사용자 프로필 오프라인 저장
  static Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    await saveOfflineData('user_profile', {
      'profile': profile,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 오프라인 사용자 프로필 조회
  static Future<Map<String, dynamic>?> getUserProfile() async {
    final data = await getOfflineData('user_profile');
    return data?['profile'] as Map<String, dynamic>?;
  }

  // 오프라인 상태 확인
  static Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // 오프라인 모드 활성화 여부 확인
  static Future<bool> shouldUseOfflineMode() async {
    final isOnlineStatus = await isOnline();
    final user = FirebaseAuth.instance.currentUser;

    // 오프라인 모드: 인터넷 연결 없거나, 사용자가 로그인 안했을 때
    return !isOnlineStatus || user == null;
  }

  // 오프라인 데이터 크기 확인
  static Future<int> getOfflineDataSize() async {
    try {
      if (_offlineDir == null) {
        await initialize();
      }

      if (!await _offlineDir!.exists()) return 0;

      int totalSize = 0;
      await for (final entity in _offlineDir!.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  // 오래된 오프라인 데이터 정리 (30일 이상)
  static Future<void> cleanupOldOfflineData() async {
    try {
      if (_offlineDir == null) {
        await initialize();
      }

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      await for (final entity in _offlineDir!.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final modified = stat.modified;

          if (modified.isBefore(thirtyDaysAgo)) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      ErrorHandler.logError(ErrorHandler.handleError(e));
    }
  }

  // 오프라인 통계 정보
  static Future<Map<String, dynamic>> getOfflineStats() async {
    try {
      final syncQueue = await getSyncQueue();
      final dataSize = await getOfflineDataSize();

      int fileCount = 0;
      int analysisCount = 0;

      if (_offlineDir != null && await _offlineDir!.exists()) {
        await for (final entity in _offlineDir!.list()) {
          if (entity is File) {
            fileCount++;
            if (entity.path.contains('analysis_')) {
              analysisCount++;
            }
          }
        }
      }

      return {
        'totalFiles': fileCount,
        'analysisResults': analysisCount,
        'syncQueueLength': syncQueue.length,
        'dataSizeBytes': dataSize,
        'dataSizeMB': (dataSize / (1024 * 1024)).toStringAsFixed(2),
        'lastCleanup': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }
}