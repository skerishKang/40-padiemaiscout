import 'package:flutter/material.dart';
import '../utils/network_checker.dart';
import '../services/cache_service.dart';
import '../models/user_profile.dart';
import '../models/uploaded_file.dart';

enum OfflineAction {
  none,
  profileUpdate,
  fileUpload,
  analysisRequest,
  suitabilityCheck,
}

class OfflineQueueItem {
  final String id;
  final OfflineAction action;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;

  OfflineQueueItem({
    required this.id,
    required this.action,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });

  OfflineQueueItem copyWith({
    String? id,
    OfflineAction? action,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    int? retryCount,
  }) {
    return OfflineQueueItem(
      id: id ?? this.id,
      action: action ?? this.action,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action.toString(),
      'data': data,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'retryCount': retryCount,
    };
  }

  factory OfflineQueueItem.fromMap(Map<String, dynamic> map) {
    return OfflineQueueItem(
      id: map['id'],
      action: OfflineAction.values.firstWhere(
        (e) => e.toString() == map['action'],
        orElse: () => OfflineAction.none,
      ),
      data: Map<String, dynamic>.from(map['data']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      retryCount: map['retryCount'] ?? 0,
    );
  }
}

class OfflineProvider extends ChangeNotifier {
  NetworkStatus _networkStatus = NetworkStatus.unknown;
  List<OfflineQueueItem> _pendingActions = [];
  bool _isProcessingQueue = false;

  NetworkStatus get networkStatus => _networkStatus;
  List<OfflineQueueItem> get pendingActions => List.unmodifiable(_pendingActions);
  bool get isOnline => _networkStatus == NetworkStatus.online;
  bool get isOffline => _networkStatus == NetworkStatus.offline;
  bool get isProcessingQueue => _isProcessingQueue;
  int get pendingActionsCount => _pendingActions.length;

  OfflineProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    // 네트워크 상태 모니터링 시작
    NetworkChecker.statusStream.listen(_onNetworkStatusChanged);
    
    // 현재 네트워크 상태 확인
    _networkStatus = NetworkChecker.status;
    
    // 저장된 오프라인 액션 로드
    await _loadPendingActions();
    
    // 온라인 상태면 대기열 처리
    if (isOnline) {
      _processOfflineQueue();
    }
    
    notifyListeners();
  }

  void _onNetworkStatusChanged(NetworkStatus status) {
    _networkStatus = status;
    notifyListeners();
    
    // 온라인으로 전환되면 대기열 처리
    if (status == NetworkStatus.online && _pendingActions.isNotEmpty) {
      _processOfflineQueue();
    }
  }

  // 오프라인 액션을 대기열에 추가
  Future<void> queueAction(OfflineAction action, Map<String, dynamic> data) async {
    final item = OfflineQueueItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      action: action,
      data: data,
      timestamp: DateTime.now(),
    );
    
    _pendingActions.add(item);
    await _savePendingActions();
    notifyListeners();
    
    debugPrint('오프라인 액션 대기열 추가: ${action.toString()}');
  }

  // 대기열에서 액션 제거
  Future<void> _removeFromQueue(String id) async {
    _pendingActions.removeWhere((item) => item.id == id);
    await _savePendingActions();
    notifyListeners();
  }

  // 오프라인 대기열 처리
  Future<void> _processOfflineQueue() async {
    if (_isProcessingQueue || _pendingActions.isEmpty) return;
    
    _isProcessingQueue = true;
    notifyListeners();
    
    debugPrint('오프라인 대기열 처리 시작: ${_pendingActions.length}개 액션');
    
    final itemsToProcess = List<OfflineQueueItem>.from(_pendingActions);
    
    for (final item in itemsToProcess) {
      if (!isOnline) break; // 중간에 오프라인이 되면 중단
      
      try {
        await _processQueueItem(item);
        await _removeFromQueue(item.id);
        debugPrint('오프라인 액션 처리 완료: ${item.action}');
      } catch (e) {
        debugPrint('오프라인 액션 처리 실패: ${item.action}, 오류: $e');
        
        // 재시도 횟수 증가
        final updatedItem = item.copyWith(retryCount: item.retryCount + 1);
        final index = _pendingActions.indexWhere((i) => i.id == item.id);
        if (index != -1) {
          _pendingActions[index] = updatedItem;
          
          // 최대 재시도 횟수 초과시 제거
          if (updatedItem.retryCount >= 3) {
            await _removeFromQueue(item.id);
            debugPrint('최대 재시도 횟수 초과, 액션 제거: ${item.action}');
          }
        }
      }
      
      // 각 작업 간 짧은 딜레이
      await Future.delayed(Duration(milliseconds: 500));
    }
    
    _isProcessingQueue = false;
    notifyListeners();
    
    debugPrint('오프라인 대기열 처리 완료');
  }

  // 개별 대기열 항목 처리
  Future<void> _processQueueItem(OfflineQueueItem item) async {
    switch (item.action) {
      case OfflineAction.profileUpdate:
        await _processProfileUpdate(item.data);
        break;
      case OfflineAction.fileUpload:
        await _processFileUpload(item.data);
        break;
      case OfflineAction.analysisRequest:
        await _processAnalysisRequest(item.data);
        break;
      case OfflineAction.suitabilityCheck:
        await _processSuitabilityCheck(item.data);
        break;
      case OfflineAction.none:
        break;
    }
  }

  // 프로필 업데이트 처리
  Future<void> _processProfileUpdate(Map<String, dynamic> data) async {
    // 실제 ProfileService.saveUserProfile 호출
    // 여기서는 시뮬레이션
    await Future.delayed(Duration(seconds: 1));
    debugPrint('프로필 업데이트 처리 완료');
  }

  // 파일 업로드 처리
  Future<void> _processFileUpload(Map<String, dynamic> data) async {
    // 실제 FileUploadService.uploadFiles 호출
    // 여기서는 시뮬레이션
    await Future.delayed(Duration(seconds: 2));
    debugPrint('파일 업로드 처리 완료');
  }

  // 분석 요청 처리
  Future<void> _processAnalysisRequest(Map<String, dynamic> data) async {
    // 실제 분석 서비스 호출
    await Future.delayed(Duration(seconds: 1));
    debugPrint('분석 요청 처리 완료');
  }

  // 적합성 검사 처리
  Future<void> _processSuitabilityCheck(Map<String, dynamic> data) async {
    // 실제 SuitabilityService.checkSuitability 호출
    await Future.delayed(Duration(seconds: 1));
    debugPrint('적합성 검사 처리 완료');
  }

  // 대기열을 저장소에 저장
  Future<void> _savePendingActions() async {
    try {
      final data = _pendingActions.map((item) => item.toMap()).toList();
      await CacheService.set('offline_queue', data, expiration: Duration(days: 7));
    } catch (e) {
      debugPrint('오프라인 대기열 저장 실패: $e');
    }
  }

  // 저장소에서 대기열 로드
  Future<void> _loadPendingActions() async {
    try {
      final data = await CacheService.get<List<dynamic>>('offline_queue');
      if (data != null) {
        _pendingActions = data
            .map((item) => OfflineQueueItem.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        debugPrint('오프라인 대기열 로드 완료: ${_pendingActions.length}개');
      }
    } catch (e) {
      debugPrint('오프라인 대기열 로드 실패: $e');
      _pendingActions = [];
    }
  }

  // 수동 재시도
  Future<void> retryPendingActions() async {
    if (isOnline && !_isProcessingQueue) {
      await _processOfflineQueue();
    }
  }

  // 특정 액션 제거
  Future<void> removeAction(String id) async {
    await _removeFromQueue(id);
  }

  // 모든 대기열 클리어
  Future<void> clearQueue() async {
    _pendingActions.clear();
    await _savePendingActions();
    notifyListeners();
    debugPrint('오프라인 대기열 모두 제거');
  }

  // 네트워크 상태 메시지
  String get networkStatusMessage {
    switch (_networkStatus) {
      case NetworkStatus.online:
        return '온라인';
      case NetworkStatus.offline:
        return '오프라인';
      case NetworkStatus.unknown:
        return '네트워크 상태 확인 중';
    }
  }

  // 대기열 통계
  Map<String, int> getQueueStats() {
    final stats = <String, int>{};
    for (final action in OfflineAction.values) {
      stats[action.toString()] = _pendingActions
          .where((item) => item.action == action)
          .length;
    }
    return stats;
  }

  @override
  void dispose() {
    super.dispose();
  }
}