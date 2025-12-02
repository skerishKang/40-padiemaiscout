import 'package:flutter_test/flutter_test.dart';
import 'package:grantscout_app/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('should create UserProfile from map', () {
      final map = {
        'companyName': 'Test Company',
        'businessType': 'Technology',
        'establishmentDate': '20230101',
        'employeeCount': 10,
        'locationRegion': 'Seoul',
        'techKeywords': ['AI', 'Flutter'],
      };

      final profile = UserProfile.fromMap(map);

      expect(profile.companyName, 'Test Company');
      expect(profile.businessType, 'Technology');
      expect(profile.establishmentDate, '20230101');
      expect(profile.employeeCount, 10);
      expect(profile.locationRegion, 'Seoul');
      expect(profile.techKeywords, ['AI', 'Flutter']);
    });

    test('should convert UserProfile to map', () {
      final profile = UserProfile(
        companyName: 'Test Company',
        businessType: 'Technology',
        establishmentDate: '20230101',
        employeeCount: 10,
        locationRegion: 'Seoul',
        techKeywords: ['AI', 'Flutter'],
      );

      final map = profile.toMap();

      expect(map['companyName'], 'Test Company');
      expect(map['businessType'], 'Technology');
      expect(map['establishmentDate'], '20230101');
      expect(map['employeeCount'], 10);
      expect(map['locationRegion'], 'Seoul');
      expect(map['techKeywords'], ['AI', 'Flutter']);
    });

    test('should validate profile correctly', () {
      final validProfile = UserProfile(
        companyName: 'Test Company',
        businessType: 'Technology',
        establishmentDate: '20230101',
        employeeCount: 10,
        locationRegion: 'Seoul',
        techKeywords: ['AI', 'Flutter'],
      );

      final invalidProfile = UserProfile(
        companyName: '',
        businessType: 'Technology',
        establishmentDate: '20230101',
        employeeCount: 0,
        locationRegion: 'Seoul',
        techKeywords: [],
      );

      expect(validProfile.isValid, true);
      expect(invalidProfile.isValid, false);
    });

    test('should handle copyWith correctly', () {
      final originalProfile = UserProfile(
        companyName: 'Original Company',
        businessType: 'Technology',
        establishmentDate: '20230101',
        employeeCount: 10,
        locationRegion: 'Seoul',
        techKeywords: ['AI'],
      );

      final updatedProfile = originalProfile.copyWith(
        companyName: 'Updated Company',
        employeeCount: 20,
      );

      expect(updatedProfile.companyName, 'Updated Company');
      expect(updatedProfile.employeeCount, 20);
      expect(updatedProfile.businessType, 'Technology'); // unchanged
      expect(updatedProfile.locationRegion, 'Seoul'); // unchanged
    });

    test('should handle equality correctly', () {
      final profile1 = UserProfile(
        companyName: 'Test Company',
        businessType: 'Technology',
        establishmentDate: '20230101',
        employeeCount: 10,
        locationRegion: 'Seoul',
        techKeywords: ['AI', 'Flutter'],
      );

      final profile2 = UserProfile(
        companyName: 'Test Company',
        businessType: 'Technology',
        establishmentDate: '20230101',
        employeeCount: 10,
        locationRegion: 'Seoul',
        techKeywords: ['AI', 'Flutter'],
      );

      final profile3 = UserProfile(
        companyName: 'Different Company',
        businessType: 'Technology',
        establishmentDate: '20230101',
        employeeCount: 10,
        locationRegion: 'Seoul',
        techKeywords: ['AI', 'Flutter'],
      );

      expect(profile1 == profile2, true);
      expect(profile1 == profile3, false);
      expect(profile1.hashCode == profile2.hashCode, true);
    });

    test('should handle empty map gracefully', () {
      final emptyMap = <String, dynamic>{};
      final profile = UserProfile.fromMap(emptyMap);

      expect(profile.companyName, '');
      expect(profile.businessType, '');
      expect(profile.establishmentDate, '');
      expect(profile.employeeCount, 0);
      expect(profile.locationRegion, '');
      expect(profile.techKeywords, []);
      expect(profile.isValid, false);
    });
  });
}