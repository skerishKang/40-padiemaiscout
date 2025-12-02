import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:math';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  // 데이터 암호화
  Future<String> encryptSensitiveData(String data, String userId) async {
    try {
      // 사용자별 고유 키 생성
      final userKey = await _generateUserKey(userId);
      final key = utf8.encode(userKey);

      // AES 암호화
      final encrypter = Encrypter(AES(key));
      final iv = IV.fromSecureRandom(16);
      final encrypted = encrypter.encrypt(data, iv: iv);

      // IV와 암호화된 데이터 결합
      return base64.encode(iv.bytes + encrypted.bytes);
    } catch (e) {
      throw SecurityException('Encryption failed: $e');
    }
  }

  // 데이터 복호화
  Future<String> decryptSensitiveData(String encryptedData, String userId) async {
    try {
      final userKey = await _generateUserKey(userId);
      final key = utf8.encode(userKey);

      final encrypter = Encrypter(AES(key));
      final combined = base64.decode(encryptedData);

      final iv = IV(combined.sublist(0, 16));
      final encrypted = combined.sublist(16);

      final decrypted = encrypter.decrypt64(base64.encode(encrypted), iv: iv);
      return decrypted;
    } catch (e) {
      throw SecurityException('Decryption failed: $e');
    }
  }

  // 접근 제어 확인
  Future<bool> checkAccessPermission(String userId, String resourceId, String action) async {
    try {
      // 사용자 역할 확인
      final userRole = await _getUserRole(userId);

      // 리소스 접근 권한 확인
      final resourcePermissions = await _getResourcePermissions(resourceId);

      // 액션 권한 확인
      return _hasPermission(userRole, resourcePermissions, action);
    } catch (e) {
      return false;
    }
  }

  // GDPR/개인정보보호 준수
  Future<bool> isCompliantWithGDPR() async {
    final compliance = await _checkComplianceStatus();
    return compliance['gdpr'] ?? false;
  }

  // 데이터 보존 정책
  Future<void> enforceDataRetentionPolicy() async {
    try {
      final now = DateTime.now();
      final retentionPeriod = Duration(days: 2555); // 7년

      // 오래된 데이터 식별
      final cutoffDate = now.subtract(retentionPeriod);

      // 사용자 데이터 정리
      await _cleanupOldUserData(cutoffDate);

      // 로그 데이터 정리
      await _cleanupOldLogs(cutoffDate);

      // 임시 데이터 정리
      await _cleanupTempData();
    } catch (e) {
      throw SecurityException('Data retention cleanup failed: $e');
    }
  }

  // 보안 감사 로깅
  Future<void> logSecurityEvent({
    required String userId,
    required String eventType,
    required String description,
    Map<String, dynamic>? metadata,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      final auditLog = {
        'userId': userId,
        'eventType': eventType,
        'description': description,
        'metadata': metadata ?? {},
        'ipAddress': ipAddress,
        'userAgent': userAgent,
        'timestamp': Timestamp.now(),
        'severity': _getEventSeverity(eventType),
      };

      // 보안 로그 저장
      await FirebaseFirestore.instance
          .collection('security_audit_logs')
          .add(auditLog);

      // 고위험 이벤트는 즉시 알림
      if (_isHighRiskEvent(eventType)) {
        await _triggerSecurityAlert(auditLog);
      }
    } catch (e) {
      // 로깅 실패 시 별도 처리
      print('Security logging failed: $e');
    }
  }

  // 이상 활동 탐지
  Future<List<SecurityAlert>> detectAnomalousActivity(String userId) async {
    final alerts = <SecurityAlert>[];

    try {
      // 최근 활동 패턴 분석
      final recentActivity = await _getRecentActivity(userId, Duration(hours: 24));

      // 비정상 로그인 시도 탐지
      final loginAnomalies = _detectLoginAnomalies(recentActivity);
      alerts.addAll(loginAnomalies);

      // 비정상 데이터 접근 탐지
      final accessAnomalies = _detectAccessAnomalies(recentActivity);
      alerts.addAll(accessAnomalies);

      // 비정상 API 사용 탐지
      final apiAnomalies = _detectAPIAnomalies(recentActivity);
      alerts.addAll(apiAnomalies);

    } catch (e) {
      throw SecurityException('Anomaly detection failed: $e');
    }

    return alerts;
  }

  // 세션 관리
  Future<void> manageUserSession(String userId, String sessionId, {
    required String action, // 'create', 'update', 'terminate'
    Map<String, dynamic>? sessionData,
  }) async {
    try {
      final sessionRef = FirebaseFirestore.instance
          .collection('user_sessions')
          .doc(sessionId);

      switch (action) {
        case 'create':
          await sessionRef.set({
            'userId': userId,
            'createdAt': Timestamp.now(),
            'lastActivity': Timestamp.now(),
            'isActive': true,
            'sessionData': sessionData ?? {},
            'ipAddress': sessionData?['ipAddress'],
            'userAgent': sessionData?['userAgent'],
          });
          break;

        case 'update':
          await sessionRef.update({
            'lastActivity': Timestamp.now(),
            'sessionData': sessionData ?? {},
          });
          break;

        case 'terminate':
          await sessionRef.update({
            'isActive': false,
            'terminatedAt': Timestamp.now(),
          });
          break;
      }

      // 비활성 세션 정리
      await _cleanupInactiveSessions();
    } catch (e) {
      throw SecurityException('Session management failed: $e');
    }
  }

  // 데이터 무결성 검증
  Future<bool> verifyDataIntegrity(String documentId, String collection) async {
    try {
      final docRef = FirebaseFirestore.instance.collection(collection).doc(documentId);
      final doc = await docRef.get();

      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final storedHash = data['dataHash'] as String?;

      if (storedHash == null) return true; // 해시가 없는 구버전

      // 현재 데이터로 해시 재계산
      final currentHash = _calculateDataHash(data);

      return currentHash == storedHash;
    } catch (e) {
      throw SecurityException('Data integrity verification failed: $e');
    }
  }

  // 비밀번호 정책 강제
  Future<bool> validatePasswordPolicy(String password) async {
    final policy = await _getPasswordPolicy();

    // 최소 길이 확인
    if (password.length < policy['minLength']) return false;

    // 복잡성 요구사항 확인
    if (policy['requireUppercase'] && !password.contains(RegExp(r'[A-Z]'))) return false;
    if (policy['requireLowercase'] && !password.contains(RegExp(r'[a-z]'))) return false;
    if (policy['requireNumbers'] && !password.contains(RegExp(r'[0-9]'))) return false;
    if (policy['requireSpecialChars'] && !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;

    // 흔한 비밀번호 체크
    if (policy['blockCommonPasswords'] && _isCommonPassword(password)) return false;

    return true;
  }

  // 백업 및 복원 보안
  Future<bool> secureBackup({bool isIncremental = false}) async {
    try {
      // 백업 시작 보안 로그
      await logSecurityEvent(
        userId: 'system',
        eventType: 'backup_initiated',
        description: 'Secure backup started',
        metadata: {'isIncremental': isIncremental},
      );

      // 데이터 암호화 백업
      final backupData = await _collectBackupData();
      final encryptedBackup = await _encryptBackupData(backupData);

      // 백업 저장
      final backupId = await _storeEncryptedBackup(encryptedBackup);

      // 백업 무결성 검증
      final isValid = await _verifyBackupIntegrity(backupId);

      if (isValid) {
        await logSecurityEvent(
          userId: 'system',
          eventType: 'backup_completed',
          description: 'Secure backup completed successfully',
          metadata: {'backupId': backupId},
        );
        return true;
      } else {
        throw SecurityException('Backup integrity verification failed');
      }
    } catch (e) {
      await logSecurityEvent(
        userId: 'system',
        eventType: 'backup_failed',
        description: 'Secure backup failed',
        metadata: {'error': e.toString()},
      );
      return false;
    }
  }

  // 개인정보 삭제 권한 확인 (Right to be forgotten)
  Future<bool> canDeleteUserData(String userId) async {
    try {
      // 법적 보유 기간 확인
      final legalHoldPeriod = await _checkLegalHoldPeriod(userId);
      if (legalHoldPeriod > DateTime.now()) {
        return false;
      }

      // 미결제 금액 확인
      final outstandingPayments = await _checkOutstandingPayments(userId);
      if (outstandingPayments > 0) {
        return false;
      }

      // 진행 중인 분쟁 확인
      final activeDisputes = await _checkActiveDisputes(userId);
      if (activeDisputes.isNotEmpty) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // 보안 설정 관리
  Future<Map<String, dynamic>> getSecuritySettings(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_security_settings')
          .doc(userId)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }

      // 기본 보안 설정 반환
      return _getDefaultSecuritySettings();
    } catch (e) {
      return _getDefaultSecuritySettings();
    }
  }

  Future<void> updateSecuritySettings(String userId, Map<String, dynamic> settings) async {
    try {
      // 설정 유효성 검증
      final validatedSettings = _validateSecuritySettings(settings);

      await FirebaseFirestore.instance
          .collection('user_security_settings')
          .doc(userId)
          .set(validatedSettings, SetOptions(merge: true));

      // 보안 설정 변경 로그
      await logSecurityEvent(
        userId: userId,
        eventType: 'security_settings_updated',
        description: 'User security settings updated',
        metadata: {'updatedFields': validatedSettings.keys.toList()},
      );
    } catch (e) {
      throw SecurityException('Security settings update failed: $e');
    }
  }

  // --- Private Helper Methods ---

  Future<String> _generateUserKey(String userId) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final userData = userDoc.data() as Map<String, dynamic>;
    final email = userData['email'] as String;
    final createdAt = userData['createdAt'] as Timestamp;

    // 사용자 고유 정보를 조합하여 키 생성
    final keyMaterial = '$userId:$email:${createdAt.millisecondsSinceEpoch}';
    final bytes = utf8.encode(keyMaterial);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  Future<String> _getUserRole(String userId) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    return userDoc.get('role') ?? 'user';
  }

  Future<Map<String, List<String>>> _getResourcePermissions(String resourceId) async {
    final resourceDoc = await FirebaseFirestore.instance
        .collection('resources')
        .doc(resourceId)
        .get();

    return Map<String, List<String>>.from(
      resourceDoc.get('permissions') ?? {'user': ['read']}
    );
  }

  bool _hasPermission(String userRole, Map<String, List<String>> permissions, String action) {
    final userPermissions = permissions[userRole] ?? [];
    return userPermissions.contains(action) || userPermissions.contains('*');
  }

  Future<Map<String, bool>> _checkComplianceStatus() async {
    return {
      'gdpr': true,
      'ccpa': true,
      'hipaa': false, // 의료 데이터가 없으므로 해당 없음
      'sox': false, // 상장사가 아니므로 해당 없음
    };
  }

  Future<void> _cleanupOldUserData(DateTime cutoffDate) async {
    final oldUsers = await FirebaseFirestore.instance
        .collection('users')
        .where('lastActiveAt', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    for (final doc in oldUsers.docs) {
      await _anonymizeUserData(doc.id);
    }
  }

  Future<void> _anonymizeUserData(String userId) async {
    // 개인정보 익명화
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    await userRef.update({
      'email': 'anonymized@deleted.com',
      'displayName': 'Deleted User',
      'phoneNumber': FieldValue.delete(),
      'address': FieldValue.delete(),
      'anonymizedAt': Timestamp.now(),
    });
  }

  String _getEventSeverity(String eventType) {
    final severityMap = {
      'login_success': 'low',
      'login_failure': 'medium',
      'password_change': 'low',
      'data_export': 'medium',
      'data_deletion': 'high',
      'access_denied': 'high',
      'security_breach': 'critical',
    };
    return severityMap[eventType] ?? 'medium';
  }

  bool _isHighRiskEvent(String eventType) {
    final highRiskEvents = [
      'access_denied',
      'security_breach',
      'data_deletion',
      'multiple_login_failures',
      'privilege_escalation',
    ];
    return highRiskEvents.contains(eventType);
  }

  Future<void> _triggerSecurityAlert(Map<String, dynamic> auditLog) async {
    // 보안팀/관리자에게 알림
    await FirebaseFirestore.instance.collection('security_alerts').add({
      ...auditLog,
      'alertLevel': 'high',
      'acknowledged': false,
      'createdAt': Timestamp.now(),
    });
  }

  Future<List<Map<String, dynamic>>> _getRecentActivity(String userId, Duration period) async {
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(period));

    final snapshot = await FirebaseFirestore.instance
        .collection('user_activity_logs')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThanThan: cutoff)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  List<SecurityAlert> _detectLoginAnomalies(List<Map<String, dynamic>> activity) {
    final alerts = <SecurityAlert>[];

    // 다수의 로그인 실패
    final failedLogins = activity.where((a) => a['eventType'] == 'login_failure').toList();
    if (failedLogins.length >= 5) {
      alerts.add(SecurityAlert(
        type: 'multiple_failed_logins',
        severity: 'high',
        description: 'Multiple failed login attempts detected',
        metadata: {'count': failedLogins.length},
      ));
    }

    // 새로운 위치/기기에서 로그인
    final successfulLogins = activity.where((a) => a['eventType'] == 'login_success').toList();
    for (final login in successfulLogins) {
      final isNewLocation = _isNewLocation(login, activity);
      if (isNewLocation) {
        alerts.add(SecurityAlert(
          type: 'new_location_login',
          severity: 'medium',
          description: 'Login from new location detected',
          metadata: {'location': login['ipAddress']},
        ));
      }
    }

    return alerts;
  }

  bool _isNewLocation(Map<String, dynamic> currentLogin, List<Map<String, dynamic>> activity) {
    final currentIP = currentLogin['ipAddress'] as String?;
    if (currentIP == null) return false;

    final pastLogins = activity.where((a) =>
        a['eventType'] == 'login_success' && a['ipAddress'] != currentIP
    ).toList();

    return pastLogins.isEmpty; // 이전에 다른 IP가 없으면 새로운 위치
  }

  List<SecurityAlert> _detectAccessAnomalies(List<Map<String, dynamic>> activity) {
    final alerts = <SecurityAlert>[];

    // 비정상적인 시간대 접근
    final nightTimeAccess = activity.where((a) {
      final timestamp = a['timestamp'] as Timestamp;
      final hour = timestamp.toDate().hour;
      return hour >= 22 || hour <= 6;
    }).toList();

    if (nightTimeAccess.length >= 3) {
      alerts.add(SecurityAlert(
        type: 'unusual_time_access',
        severity: 'medium',
        description: 'Multiple night-time access detected',
        metadata: {'count': nightTimeAccess.length},
      ));
    }

    return alerts;
  }

  List<SecurityAlert> _detectAPIAnomalies(List<Map<String, dynamic>> activity) {
    final alerts = <SecurityAlert>[];

    // 과도한 API 호출
    final apiCalls = activity.where((a) => a['eventType'] == 'api_call').toList();
    if (apiCalls.length >= 100) { // 24시간 동안 100회 이상
      alerts.add(SecurityAlert(
        type: 'excessive_api_usage',
        severity: 'medium',
        description: 'Excessive API usage detected',
        metadata: {'count': apiCalls.length},
      ));
    }

    return alerts;
  }

  String _calculateDataHash(Map<String, dynamic> data) {
    // 해시 계산에서 제외할 필드
    final excludedFields = ['dataHash', 'lastModified', 'version'];

    final filteredData = Map<String, dynamic>.from(data)
      ..removeWhere((key, value) => excludedFields.contains(key));

    final jsonString = json.encode(filteredData);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  bool _isCommonPassword(String password) {
    final commonPasswords = [
      'password', '123456', '123456789', 'qwerty', 'abc123',
      'password123', 'admin', 'letmein', 'welcome', 'monkey'
    ];

    return commonPasswords.contains(password.toLowerCase());
  }

  Future<Map<String, dynamic>> _getPasswordPolicy() async {
    return {
      'minLength': 8,
      'requireUppercase': true,
      'requireLowercase': true,
      'requireNumbers': true,
      'requireSpecialChars': true,
      'blockCommonPasswords': true,
      'maxAge': 90, // days
    };
  }

  Map<String, dynamic> _getDefaultSecuritySettings() {
    return {
      'twoFactorEnabled': false,
      'emailNotifications': true,
      'sessionTimeout': 30, // minutes
      'loginAlerts': true,
      'dataExportEnabled': true,
      'privacyMode': false,
    };
  }

  Map<String, dynamic> _validateSecuritySettings(Map<String, dynamic> settings) {
    final validated = <String, dynamic>{};

    // 유효한 설정만 포함
    if (settings.containsKey('twoFactorEnabled')) {
      validated['twoFactorEnabled'] = settings['twoFactorEnabled'] as bool? ?? false;
    }

    if (settings.containsKey('emailNotifications')) {
      validated['emailNotifications'] = settings['emailNotifications'] as bool? ?? true;
    }

    if (settings.containsKey('sessionTimeout')) {
      final timeout = (settings['sessionTimeout'] as int?) ?? 30;
      validated['sessionTimeout'] = timeout.clamp(5, 120); // 5분-2시간
    }

    return validated;
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}

class SecurityAlert {
  final String type;
  final String severity;
  final String description;
  final Map<String, dynamic> metadata;

  SecurityAlert({
    required this.type,
    required this.severity,
    required this.description,
    required this.metadata,
  });
}