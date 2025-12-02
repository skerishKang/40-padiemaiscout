import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../utils/file_utils.dart';

class SuitabilityService {
  static Future<Map<String, dynamic>> checkSuitability(Map<String, dynamic> analysisResult) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('로그인 후 이용 가능합니다.');
    }

    final doc = await FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(user.uid)
        .get();
        
    if (!doc.exists) {
      throw Exception('회사 정보가 없습니다. 먼저 회사 정보를 저장해 주세요.');
    }

    final userProfile = doc.data();
    if (userProfile == null) {
      throw Exception('회사 정보 로딩 오류');
    }

    // JSON 직렬화 안전하게 변환
    final safeUserProfile = FileUtils.toJsonSafe(userProfile);
    final safeAnalysisResult = FileUtils.toJsonSafe(analysisResult);

    final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('checkSuitability');
        
    final result = await callable.call({
      'userProfile': safeUserProfile,
      'analysisResult': safeAnalysisResult,
    });

    final data = result.data;
    if (data['status'] == 'ok') {
      return data;
    } else {
      throw Exception('분석 실패: ${data['message'] ?? '알 수 없는 오류'}');
    }
  }
}