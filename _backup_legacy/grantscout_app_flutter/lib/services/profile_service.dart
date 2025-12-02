import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';

class ProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'user_profiles';

  static Future<UserProfile?> getCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final docSnapshot = await _firestore
          .collection(_collectionName)
          .doc(user.uid)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        return UserProfile.fromMap(docSnapshot.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('프로필 로딩 중 오류 발생: $e');
    }
  }

  static Future<void> saveUserProfile(UserProfile profile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      final profileData = profile.toMap();
      profileData['lastUpdated'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(_collectionName)
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));
    } catch (e) {
      throw Exception('프로필 저장 중 오류 발생: $e');
    }
  }

  static Future<bool> hasUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final docSnapshot = await _firestore
          .collection(_collectionName)
          .doc(user.uid)
          .get();
      return docSnapshot.exists;
    } catch (e) {
      return false;
    }
  }

  static Stream<UserProfile?> watchUserProfile() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection(_collectionName)
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserProfile.fromMap(snapshot.data()!);
      }
      return null;
    });
  }

  static Future<void> deleteUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection(_collectionName)
          .doc(user.uid)
          .delete();
    } catch (e) {
      throw Exception('프로필 삭제 중 오류 발생: $e');
    }
  }
}