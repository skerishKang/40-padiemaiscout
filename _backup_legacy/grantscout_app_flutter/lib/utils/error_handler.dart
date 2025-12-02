import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AppError {
  final String code;
  final String message;
  final String userMessage;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final Map<String, dynamic>? context;

  AppError({
    required this.code,
    required this.message,
    required this.userMessage,
    this.stackTrace,
    Map<String, dynamic>? context,
  }) : timestamp = DateTime.now(),
       context = context ?? {};

  @override
  String toString() {
    return 'AppError(code: $code, message: $message, timestamp: $timestamp)';
  }
}

class ErrorHandler {
  static final Map<String, String> _firebaseAuthErrors = {
    'user-not-found': '등록되지 않은 이메일입니다.',
    'wrong-password': '비밀번호가 올바르지 않습니다.',
    'user-disabled': '비활성화된 계정입니다.',
    'too-many-requests': '너무 많은 시도가 있었습니다. 잠시 후 다시 시도해주세요.',
    'operation-not-allowed': '이 작업은 허용되지 않습니다.',
    'weak-password': '비밀번호가 너무 약합니다.',
    'email-already-in-use': '이미 사용 중인 이메일입니다.',
    'invalid-email': '올바르지 않은 이메일 형식입니다.',
    'requires-recent-login': '보안을 위해 다시 로그인해주세요.',
    'network-request-failed': '네트워크 연결을 확인해주세요.',
  };

  static final Map<String, String> _firestoreErrors = {
    'permission-denied': '접근 권한이 없습니다.',
    'not-found': '요청한 데이터를 찾을 수 없습니다.',
    'already-exists': '이미 존재하는 데이터입니다.',
    'resource-exhausted': '할당량을 초과했습니다. 잠시 후 다시 시도해주세요.',
    'failed-precondition': '작업 조건이 충족되지 않았습니다.',
    'aborted': '작업이 중단되었습니다. 다시 시도해주세요.',
    'out-of-range': '범위를 벗어난 요청입니다.',
    'unimplemented': '지원하지 않는 기능입니다.',
    'internal': '내부 오류가 발생했습니다.',
    'unavailable': '서비스를 일시적으로 사용할 수 없습니다.',
    'data-loss': '데이터 손실이 발생했습니다.',
    'unauthenticated': '인증이 필요합니다.',
  };

  static final Map<String, String> _storageErrors = {
    'object-not-found': '파일을 찾을 수 없습니다.',
    'bucket-not-found': '저장소를 찾을 수 없습니다.',
    'project-not-found': '프로젝트를 찾을 수 없습니다.',
    'quota-exceeded': '저장 용량을 초과했습니다.',
    'unauthenticated': '인증이 필요합니다.',
    'unauthorized': '파일에 대한 접근 권한이 없습니다.',
    'retry-limit-exceeded': '재시도 횟수를 초과했습니다.',
    'invalid-checksum': '파일이 손상되었습니다.',
    'canceled': '업로드가 취소되었습니다.',
    'invalid-event-name': '잘못된 이벤트입니다.',
    'invalid-url': '잘못된 URL입니다.',
    'invalid-argument': '잘못된 매개변수입니다.',
    'no-default-bucket': '기본 저장소가 설정되지 않았습니다.',
    'cannot-slice-blob': '파일을 처리할 수 없습니다.',
    'server-file-wrong-size': '서버의 파일 크기가 올바르지 않습니다.',
  };

  static AppError handleError(dynamic error, {Map<String, dynamic>? context}) {
    if (error is AppError) {
      return error;
    }

    String code = 'unknown';
    String message = error.toString();
    String userMessage = '알 수 없는 오류가 발생했습니다.';
    StackTrace? stackTrace;

    if (error is Exception) {
      stackTrace = StackTrace.current;
    }

    // Firebase Auth 에러 처리
    if (error is FirebaseAuthException) {
      code = 'auth-${error.code}';
      message = error.message ?? error.toString();
      userMessage = _firebaseAuthErrors[error.code] ?? '인증 중 오류가 발생했습니다.';
    }
    // Firestore 에러 처리
    else if (error is FirebaseException && error.plugin == 'cloud_firestore') {
      code = 'firestore-${error.code}';
      message = error.message ?? error.toString();
      userMessage = _firestoreErrors[error.code] ?? '데이터베이스 오류가 발생했습니다.';
    }
    // Firebase Storage 에러 처리
    else if (error is FirebaseException && error.plugin == 'firebase_storage') {
      code = 'storage-${error.code}';
      message = error.message ?? error.toString();
      userMessage = _storageErrors[error.code] ?? '파일 처리 중 오류가 발생했습니다.';
    }
    // Platform 에러 처리
    else if (error is PlatformException) {
      code = 'platform-${error.code}';
      message = error.message ?? error.toString();
      userMessage = '시스템 오류가 발생했습니다.';
    }
    // 네트워크 에러 처리
    else if (error.toString().contains('SocketException') || 
             error.toString().contains('NetworkException')) {
      code = 'network-error';
      userMessage = '네트워크 연결을 확인해주세요.';
    }
    // 타임아웃 에러 처리
    else if (error.toString().contains('TimeoutException')) {
      code = 'timeout-error';
      userMessage = '요청 시간이 초과되었습니다. 다시 시도해주세요.';
    }

    return AppError(
      code: code,
      message: message,
      userMessage: userMessage,
      stackTrace: stackTrace,
      context: context,
    );
  }

  static void showErrorDialog(BuildContext context, AppError error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('오류 발생'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error.userMessage),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('상세 정보'),
              children: [
                SelectableText('코드: ${error.code}'),
                const SizedBox(height: 4),
                SelectableText('시간: ${error.timestamp}'),
                if (error.message != error.userMessage) ...[
                  const SizedBox(height: 4),
                  SelectableText('메시지: ${error.message}'),
                ],
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  static void showErrorSnackBar(BuildContext context, AppError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(error.userMessage)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '상세',
          textColor: Colors.white,
          onPressed: () => showErrorDialog(context, error),
        ),
      ),
    );
  }

  static void logError(AppError error) {
    debugPrint('=== ERROR LOG ===');
    debugPrint('Code: ${error.code}');
    debugPrint('Message: ${error.message}');
    debugPrint('User Message: ${error.userMessage}');
    debugPrint('Timestamp: ${error.timestamp}');
    if (error.context?.isNotEmpty == true) {
      debugPrint('Context: ${error.context}');
    }
    if (error.stackTrace != null) {
      debugPrint('Stack Trace:\n${error.stackTrace}');
    }
    debugPrint('==================');
  }
}

// Global error handler for uncaught errors
class GlobalErrorHandler {
  static void initialize() {
    FlutterError.onError = (FlutterErrorDetails details) {
      final error = AppError(
        code: 'flutter-error',
        message: details.exceptionAsString(),
        userMessage: '앱에서 예상치 못한 오류가 발생했습니다.',
        stackTrace: details.stack,
        context: {
          'library': details.library,
          'context': details.context?.toString(),
        },
      );
      
      ErrorHandler.logError(error);
      
      // In development, show the red error screen
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };
  }
}