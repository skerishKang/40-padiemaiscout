import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';

class MockSetup {
  static Future<void> setupFirebase() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase with mock
    await Firebase.initializeApp();
  }

  static Widget createTestApp({required Widget child}) {
    return MaterialApp(
      home: child,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
    );
  }

  static FakeFirebaseFirestore createMockFirestore() {
    return FakeFirebaseFirestore();
  }

  static MockFirebaseStorage createMockStorage() {
    return MockFirebaseStorage();
  }

  static Map<String, dynamic> createSampleUserProfile() {
    return {
      'companyName': 'Test Company',
      'businessType': 'Technology',
      'establishmentDate': '20230101',
      'employeeCount': 10,
      'locationRegion': 'Seoul',
      'techKeywords': ['AI', 'Flutter'],
      'lastUpdated': DateTime.now(),
    };
  }

  static Map<String, dynamic> createSampleUploadedFile() {
    return {
      'userId': 'test-user-id',
      'fileName': 'test-file.pdf',
      'storagePath': 'uploads/test-user-id/test-file_123456.pdf',
      'downloadUrl': 'https://example.com/test-file.pdf',
      'fileSize': 1024000,
      'uploadedAt': DateTime.now(),
      'analysisStatus': 'analysis_success',
      'analysisResult': {
        '사업명': 'AI 스타트업 지원사업',
        '주관기관': '과학기술정보통신부',
        '지원대상_요약': '인공지능 스타트업',
        '신청자격_상세': '설립 5년 이내, 직원 50명 이하',
        '지원내용': '사업화 자금 지원',
        '지원규모_금액': '최대 1억원',
        '신청기간_시작일': '2024-01-01',
        '신청기간_종료일': '2024-12-31',
        '신청방법': '온라인 접수',
        '지원기간_협약기간': '12개월',
        '신청제외대상_요약': '대기업 계열사 제외',
        '사업분야_키워드': ['AI', '머신러닝', '스타트업'],
      },
      'extractedTextRaw': 'Raw text content from PDF...',
    };
  }

  static Future<void> pumpWidget(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(createTestApp(child: widget));
    await tester.pumpAndSettle();
  }

  static Finder findByText(String text) {
    return find.text(text);
  }

  static Finder findByKey(String key) {
    return find.byKey(Key(key));
  }

  static Finder findByType(Type type) {
    return find.byType(type);
  }

  static Future<void> tapButton(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  static Future<void> enterText(WidgetTester tester, Finder finder, String text) async {
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  static void expectToFindText(String text) {
    expect(find.text(text), findsOneWidget);
  }

  static void expectToFindWidget(Type type) {
    expect(find.byType(type), findsOneWidget);
  }

  static void expectNotToFindText(String text) {
    expect(find.text(text), findsNothing);
  }
}

// Custom matchers for better test readability
class TextFieldMatcher extends Matcher {
  final String hintText;

  TextFieldMatcher(this.hintText);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! TextField) return false;
    return item.decoration?.hintText == hintText;
  }

  @override
  Description describe(Description description) {
    return description.add('TextField with hint text "$hintText"');
  }
}

Matcher hasHintText(String hintText) => TextFieldMatcher(hintText);

// Test data generators
class TestDataGenerator {
  static Map<String, dynamic> generateUserProfile({
    String companyName = 'Test Company',
    String businessType = 'Technology',
    String establishmentDate = '20230101',
    int employeeCount = 10,
    String locationRegion = 'Seoul',
    List<String> techKeywords = const ['AI', 'Flutter'],
  }) {
    return {
      'companyName': companyName,
      'businessType': businessType,
      'establishmentDate': establishmentDate,
      'employeeCount': employeeCount,
      'locationRegion': locationRegion,
      'techKeywords': techKeywords,
      'lastUpdated': DateTime.now(),
    };
  }

  static Map<String, dynamic> generateAnalysisResult({
    String businessName = '테스트 지원사업',
    String organization = '테스트 기관',
    String deadline = '2024-12-31',
  }) {
    return {
      '사업명': businessName,
      '주관기관': organization,
      '지원대상_요약': '중소기업 및 스타트업',
      '신청자격_상세': '설립 3년 이내, 직원 20명 이하',
      '지원내용': '사업화 자금 지원',
      '지원규모_금액': '최대 5천만원',
      '신청기간_시작일': '2024-01-01',
      '신청기간_종료일': deadline,
      '신청방법': '온라인 접수',
      '지원기간_협약기간': '12개월',
      '신청제외대상_요약': '대기업 계열사 제외',
      '사업분야_키워드': ['기술개발', '스타트업'],
    };
  }
}