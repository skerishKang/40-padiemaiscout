import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus {
  online,
  offline,
  unknown,
}

class NetworkChecker {
  static final Connectivity _connectivity = Connectivity();
  static NetworkStatus _status = NetworkStatus.unknown;
  static StreamController<NetworkStatus>? _controller;

  static NetworkStatus get status => _status;
  static Stream<NetworkStatus> get statusStream {
    _controller ??= StreamController<NetworkStatus>.broadcast();
    return _controller!.stream;
  }

  static Future<void> initialize() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateStatus(result);
      
      _connectivity.onConnectivityChanged.listen(_updateStatus);
    } catch (e) {
      debugPrint('네트워크 상태 확인 초기화 실패: $e');
      _status = NetworkStatus.unknown;
    }
  }

  static void _updateStatus(ConnectivityResult result) {
    final oldStatus = _status;
    
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.mobile:
      case ConnectivityResult.ethernet:
        _status = NetworkStatus.online;
        break;
      case ConnectivityResult.none:
        _status = NetworkStatus.offline;
        break;
      default:
        _status = NetworkStatus.unknown;
    }

    if (oldStatus != _status) {
      _controller?.add(_status);
      debugPrint('네트워크 상태 변경: $oldStatus -> $_status');
    }
  }

  static Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      debugPrint('네트워크 연결 확인 실패: $e');
      return false;
    }
  }

  static String getStatusMessage(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.online:
        return '인터넷에 연결되어 있습니다.';
      case NetworkStatus.offline:
        return '인터넷 연결이 없습니다.';
      case NetworkStatus.unknown:
        return '네트워크 상태를 확인할 수 없습니다.';
    }
  }

  static void dispose() {
    _controller?.close();
    _controller = null;
  }
}