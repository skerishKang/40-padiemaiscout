import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'widgets/auth_gate.dart';
import 'utils/error_handler.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 전역 에러 핸들러 초기화
  GlobalErrorHandler.initialize();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 로컬 환경(디버그)에서만 에뮬레이터 연결
    if (kDebugMode) {
      try {
        FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
        await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
        FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
        print("Using local Firebase emulators");
      } catch (e) {
        final error = ErrorHandler.handleError(e);
        ErrorHandler.logError(error);
      }
    }

    // 웹 환경에서 로그인 지속성 설정
    if (kIsWeb) {
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        debugPrint('Firebase Auth persistence set to LOCAL for web.');
      } catch (e) {
        final error = ErrorHandler.handleError(e);
        ErrorHandler.logError(error);
      }
    }
  } catch (e) {
    final error = ErrorHandler.handleError(e, context: {'location': 'main_initialization'});
    ErrorHandler.logError(error);
  }

  runApp(const GrantScoutApp());
}

        // TODO: 다국어 지원 추가 시
      ],
      supportedLocales: const [
        Locale('ko', 'KR'), // 한국어
        Locale('en', 'US'), // 영어
      ],
    );
  }
}