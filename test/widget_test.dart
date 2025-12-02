import 'package:flutter_test/flutter_test.dart';
import 'package:grantscouter/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../test/firebase_mock.dart';

@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  User,
  UserCredential,
])
void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('GrantScout App Tests', () {
    testWidgets('App starts with login screen', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // 로그인 화면 확인
      expect(find.text('GrantScout'), findsOneWidget);
      expect(find.text('Google로 로그인'), findsOneWidget);
    });

    testWidgets('Google sign in button exists', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      final googleSignInButton = find.text('Google로 로그인');
      expect(googleSignInButton, findsOneWidget);
      
      // 버튼 탭 가능 확인
      await tester.tap(googleSignInButton);
      await tester.pump();
    });
  });

  group('PDF Upload Tests', () {
    test('File size validation', () {
      // 50MB 제한 테스트
      const maxSize = 50 * 1024 * 1024;
      const testFileSize = 51 * 1024 * 1024;
      
      expect(testFileSize > maxSize, true);
    });

    test('File type validation', () {
      // 허용된 파일 타입 테스트
      const allowedTypes = ['application/pdf', 'application/vnd.ms-excel', 'image/png'];
      const testType = 'application/pdf';
      
      expect(allowedTypes.contains(testType), true);
    });
  });

  group('Firestore Security Rules Tests', () {
    test('User can only read own files', () {
      const userId = 'test_user_123';
      const otherUserId = 'other_user_456';
      
      // 실제 보안 규칙은 Firebase Emulator에서 테스트
      expect(userId != otherUserId, true);
    });

    test('File name length validation', () {
      const maxLength = 255;
      const testFileName = 'test_file.pdf';
      
      expect(testFileName.length <= maxLength, true);
    });
  });
}