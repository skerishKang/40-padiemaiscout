import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;

class PerformanceMonitor {
  static final Map<String, Stopwatch> _stopwatches = {};
  static final Map<String, List<int>> _measurements = {};
  static bool _isEnabled = kDebugMode;

  // 성능 모니터링 활성화/비활성화
  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  // 측정 시작
  static void startMeasurement(String name) {
    if (!_isEnabled) return;
    
    final stopwatch = Stopwatch()..start();
    _stopwatches[name] = stopwatch;
    developer.log('성능 측정 시작: $name', name: 'PerformanceMonitor');
  }

  // 측정 종료
  static int endMeasurement(String name) {
    if (!_isEnabled) return 0;
    
    final stopwatch = _stopwatches[name];
    if (stopwatch == null) {
      developer.log('측정이 시작되지 않았습니다: $name', name: 'PerformanceMonitor');
      return 0;
    }
    
    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMilliseconds;
    
    // 측정 기록 저장
    _measurements.putIfAbsent(name, () => []).add(elapsedMs);
    _stopwatches.remove(name);
    
    developer.log('성능 측정 완료: $name - ${elapsedMs}ms', name: 'PerformanceMonitor');
    
    // 임계값 체크
    _checkThreshold(name, elapsedMs);
    
    return elapsedMs;
  }

  // 임계값 체크 및 경고
  static void _checkThreshold(String name, int elapsedMs) {
    final thresholds = {
      'file_upload': 10000, // 10초
      'analysis': 30000, // 30초
      'database_query': 2000, // 2초
      'api_call': 5000, // 5초
      'ui_render': 100, // 100ms
    };
    
    final threshold = thresholds.entries
        .firstWhere(
          (entry) => name.contains(entry.key),
          orElse: () => const MapEntry('default', 1000),
        )
        .value;
    
    if (elapsedMs > threshold) {
      developer.log(
        '⚠️ 성능 경고: $name이 임계값을 초과했습니다 (${elapsedMs}ms > ${threshold}ms)',
        name: 'PerformanceMonitor',
        level: 900, // Warning level
      );
    }
  }

  // 측정 통계 반환
  static Map<String, dynamic> getStatistics(String name) {
    final measurements = _measurements[name];
    if (measurements == null || measurements.isEmpty) {
      return {'count': 0};
    }
    
    measurements.sort();
    final count = measurements.length;
    final sum = measurements.reduce((a, b) => a + b);
    final avg = sum / count;
    final min = measurements.first;
    final max = measurements.last;
    final median = count % 2 == 0
        ? (measurements[count ~/ 2 - 1] + measurements[count ~/ 2]) / 2
        : measurements[count ~/ 2].toDouble();
    
    return {
      'count': count,
      'sum': sum,
      'average': avg.round(),
      'min': min,
      'max': max,
      'median': median.round(),
    };
  }

  // 모든 측정 통계 반환
  static Map<String, Map<String, dynamic>> getAllStatistics() {
    return Map.fromEntries(
      _measurements.keys.map((key) => MapEntry(key, getStatistics(key))),
    );
  }

  // 측정 기록 초기화
  static void clearMeasurements([String? name]) {
    if (name != null) {
      _measurements.remove(name);
    } else {
      _measurements.clear();
    }
  }

  // 메모리 사용량 모니터링
  static Future<Map<String, dynamic>> getMemoryUsage() async {
    if (!_isEnabled) return {};
    
    try {
      final memoryInfo = await _getMemoryInfo();
      return memoryInfo;
    } catch (e) {
      developer.log('메모리 정보 조회 실패: $e', name: 'PerformanceMonitor');
      return {};
    }
  }

  static Future<Map<String, dynamic>> _getMemoryInfo() async {
    if (kIsWeb) {
      // 웹에서는 제한적인 메모리 정보만 제공
      return {'platform': 'web', 'note': 'Limited memory info on web'};
    }
    
    try {
      // 플랫폼별 메모리 정보 조회
      const platform = MethodChannel('performance_monitor');
      final result = await platform.invokeMethod<Map>('getMemoryInfo');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      // 네이티브 채널이 없으면 기본 정보만 반환
      return {
        'error': e.message,
        'dartVmHeapSize': _getDartVmHeapSize(),
      };
    }
  }

  static int _getDartVmHeapSize() {
    try {
      // Dart VM 힙 크기 추정 (정확하지 않음)
      return developer.Service.getIsolateID(Isolate.current).hashCode;
    } catch (e) {
      return 0;
    }
  }

  // FPS 모니터링 (간단한 구현)
  static void monitorFrameRate() {
    if (!_isEnabled) return;
    
    WidgetsBinding.instance.addTimingsCallback(_onFrameTiming);
  }

  static void _onFrameTiming(List<FrameTiming> timings) {
    for (final timing in timings) {
      final frameDuration = timing.totalSpan.inMicroseconds / 1000; // ms로 변환
      
      if (frameDuration > 16.67) { // 60fps 기준
        developer.log(
          '⚠️ 프레임 드롭 감지: ${frameDuration.toStringAsFixed(1)}ms',
          name: 'PerformanceMonitor',
          level: 800,
        );
      }
    }
  }

  // 네트워크 요청 모니터링
  static void logNetworkRequest({
    required String url,
    required String method,
    required int statusCode,
    required int duration,
    int? responseSize,
  }) {
    if (!_isEnabled) return;
    
    final logLevel = statusCode >= 400 ? 900 : 800;
    developer.log(
      'HTTP $method $url - $statusCode (${duration}ms${responseSize != null ? ', ${responseSize}B' : ''})',
      name: 'NetworkMonitor',
      level: logLevel,
    );
    
    // 네트워크 요청 통계 저장
    final key = 'network_${method.toLowerCase()}';
    _measurements.putIfAbsent(key, () => []).add(duration);
  }

  // 예외 및 에러 로깅
  static void logError({
    required String error,
    String? stackTrace,
    Map<String, dynamic>? context,
  }) {
    developer.log(
      'ERROR: $error',
      name: 'ErrorMonitor',
      level: 1000, // Severe level
      error: error,
      stackTrace: stackTrace != null ? StackTrace.fromString(stackTrace) : null,
    );
  }

  // 사용자 액션 추적
  static void logUserAction({
    required String action,
    Map<String, dynamic>? parameters,
  }) {
    if (!_isEnabled) return;
    
    developer.log(
      'USER_ACTION: $action${parameters != null ? ' $parameters' : ''}',
      name: 'UserActionMonitor',
    );
  }

  // 성능 보고서 생성
  static Map<String, dynamic> generateReport() {
    final stats = getAllStatistics();
    final memoryPromise = getMemoryUsage();
    
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'measurements': stats,
      'totalMeasurements': stats.values.fold<int>(
        0,
        (sum, stat) => sum + (stat['count'] as int? ?? 0),
      ),
      'platform': {
        'isDebugMode': kDebugMode,
        'isReleaseMode': kReleaseMode,
        'isProfileMode': kProfileMode,
        'isWeb': kIsWeb,
      },
      'note': 'Memory usage requires async call',
    };
  }

  // 성능 보고서 출력
  static void printReport() {
    if (!_isEnabled) return;
    
    final report = generateReport();
    developer.log(
      '📊 성능 보고서\n${_formatReport(report)}',
      name: 'PerformanceMonitor',
    );
  }

  static String _formatReport(Map<String, dynamic> report) {
    final buffer = StringBuffer();
    buffer.writeln('생성 시간: ${report['timestamp']}');
    buffer.writeln('총 측정 횟수: ${report['totalMeasurements']}');
    buffer.writeln();
    
    final measurements = report['measurements'] as Map<String, dynamic>;
    if (measurements.isEmpty) {
      buffer.writeln('측정 데이터가 없습니다.');
    } else {
      buffer.writeln('측정 통계:');
      measurements.forEach((name, stats) {
        final s = stats as Map<String, dynamic>;
        buffer.writeln('  $name: ${s['count']}회, 평균 ${s['average']}ms, 최소 ${s['min']}ms, 최대 ${s['max']}ms');
      });
    }
    
    return buffer.toString();
  }
}

// 성능 측정을 위한 유틸리티 함수들
extension PerformanceMeasurement on Future<T> {
  Future<T> measurePerformance<T>(String name) async {
    PerformanceMonitor.startMeasurement(name);
    try {
      final result = await this;
      return result;
    } finally {
      PerformanceMonitor.endMeasurement(name);
    }
  }
}

// 위젯 성능 측정을 위한 래퍼
class PerformanceMeasuredWidget extends StatefulWidget {
  final Widget child;
  final String name;

  const PerformanceMeasuredWidget({
    super.key,
    required this.child,
    required this.name,
  });

  @override
  State<PerformanceMeasuredWidget> createState() => _PerformanceMeasuredWidgetState();
}

class _PerformanceMeasuredWidgetState extends State<PerformanceMeasuredWidget> {
  @override
  void initState() {
    super.initState();
    PerformanceMonitor.startMeasurement('widget_${widget.name}_build');
  }

  @override
  void dispose() {
    PerformanceMonitor.endMeasurement('widget_${widget.name}_build');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}