import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

enum NotificationType {
  grantMatch('지원사업 매칭'),
  deadlineReminder('마감일 알림'),
  analysisComplete('분석 완료'),
  workflowUpdate('워크플로우 업데이트'),
  teamActivity('팀 활동'),
  systemAlert('시스템 알림'),
  securityAlert('보안 알림'),
  custom('사용자 정의');

  const NotificationType(this.displayName);
  final String displayName;
}

enum NotificationPriority {
  low('낮음'),
  normal('보통'),
  high('높음'),
  urgent('긴급');

  const NotificationPriority(this.displayName);
  final String displayName;
}

enum NotificationChannel {
  push('푸시 알림'),
  email('이메일'),
  sms('SMS'),
  inApp('인앱 알림'),
  webhook('웹훅');

  const NotificationChannel(this.displayName);
  final String displayName;
}

class NotificationMessage {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final NotificationPriority priority;
  final Map<String, dynamic> data;
  final List<NotificationChannel> channels;
  final bool isRead;
  final Timestamp createdAt;
  final Timestamp? scheduledFor;
  final Timestamp? expiresAt;
  final String? imageUrl;
  final List<NotificationAction> actions;

  const NotificationMessage({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.priority,
    this.data = const {},
    this.channels = const [NotificationChannel.push, NotificationChannel.inApp],
    this.isRead = false,
    required this.createdAt,
    this.scheduledFor,
    this.expiresAt,
    this.imageUrl,
    this.actions = const [],
  });
}

class NotificationAction {
  final String id;
  final String title;
  final String? url;
  final Map<String, dynamic>? parameters;

  const NotificationAction({
    required this.id,
    required this.title,
    this.url,
    this.parameters,
  });
}

class ReminderRule {
  final String id;
  final String name;
  final String description;
  final String triggerType; // 'deadline', 'event', 'recurring'
  final Map<String, dynamic> triggerConfig;
  final List<NotificationChannel> channels;
  final String template;
  final bool isActive;
  final String createdBy;
  final Timestamp createdAt;

  const ReminderRule({
    required this.id,
    required this.name,
    required this.description,
    required this.triggerType,
    required this.triggerConfig,
    this.channels = const [NotificationChannel.push],
    required this.template,
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamController<NotificationMessage>? _notificationStream;
  Timer? _reminderTimer;

  Future<void> initialize() async {
    // 로컬 알림 초기화
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    // 예약 알림 처리 시작
    _startScheduledNotificationProcessor();

    // 리마인더 규칙 처리 시작
    _startReminderProcessor();
  }

  // 알림 생성 및 발송
  Future<String> sendNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic> data = const {},
    List<NotificationChannel> channels = const [NotificationChannel.push, NotificationChannel.inApp],
    String? imageUrl,
    List<NotificationAction> actions = const [],
    DateTime? scheduledFor,
    DateTime? expiresAt,
  }) async {
    try {
      final notificationId = _generateNotificationId();

      final notification = NotificationMessage(
        id: notificationId,
        userId: userId,
        title: title,
        body: body,
        type: type,
        priority: priority,
        data: data,
        channels: channels,
        createdAt: Timestamp.now(),
        scheduledFor: scheduledFor != null ? Timestamp.fromDate(scheduledFor) : null,
        expiresAt: expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        imageUrl: imageUrl,
        actions: actions,
      );

      // 데이터베이스에 저장
      await _saveNotification(notification);

      // 예약 알림이 아니면 즉시 발송
      if (scheduledFor == null) {
        await _deliverNotification(notification);
      }

      return notificationId;
    } catch (e) {
      throw NotificationException('Failed to send notification: $e');
    }
  }

  // 마감일 리마인더 생성
  Future<List<String>> createDeadlineReminders({
    required String userId,
    required String grantId,
    required DateTime deadline,
    List<int> daysBefore = const [7, 3, 1],
    bool includeHourly = true,
  }) async {
    final reminderIds = <String>[];

    try {
      // 일 단위 리마인더
      for (final days in daysBefore) {
        final reminderDate = deadline.subtract(Duration(days: days));

        if (reminderDate.isAfter(DateTime.now())) {
          final reminderId = await sendNotification(
            userId: userId,
            title: '지원사업 마감일 알림',
            body: '${deadline.difference(DateTime.now()).inDays}일 남은 지원사업이 있습니다.',
            type: NotificationType.deadlineReminder,
            priority: days <= 1 ? NotificationPriority.high : NotificationPriority.normal,
            scheduledFor: reminderDate,
            data: {
              'grantId': grantId,
              'deadline': deadline.toIso8601String(),
              'daysBefore': days,
            },
            actions: [
              NotificationAction(
                id: 'view_grant',
                title: '지원사업 보기',
                url: '/grants/$grantId',
              ),
            ],
          );

          reminderIds.add(reminderId);
        }
      }

      // 시간 단위 리마인더 (마감일 24시간)
      if (includeHourly && deadline.difference(DateTime.now()).inDays <= 1) {
        final hoursLeft = deadline.difference(DateTime.now()).inHours;

        for (int i = min(24, hoursLeft); i > 0; i -= 3) { // 3시간 간격
          final reminderDate = deadline.subtract(Duration(hours: i));

          if (reminderDate.isAfter(DateTime.now())) {
            final reminderId = await sendNotification(
              userId: userId,
              title: '긴급: 지원사업 마감 임박',
              body: '${i}시간 후 마감됩니다.',
              type: NotificationType.deadlineReminder,
              priority: NotificationPriority.urgent,
              scheduledFor: reminderDate,
              data: {
                'grantId': grantId,
                'deadline': deadline.toIso8601String(),
                'hoursLeft': i,
              },
            );

            reminderIds.add(reminderId);
          }
        }
      }

      return reminderIds;
    } catch (e) {
      throw NotificationException('Failed to create deadline reminders: $e');
    }
  }

  // 개인화된 알림 생성
  Future<String> sendPersonalizedNotification({
    required String userId,
    required String templateId,
    Map<String, dynamic> templateData = const {},
    Map<String, dynamic> overrideData = const {},
  }) async {
    try {
      // 템플릿 조회
      final template = await _getNotificationTemplate(templateId);
      if (template == null) {
        throw NotificationException('Template not found: $templateId');
      }

      // 사용자 선호도 조회
      final userPreferences = await _getUserNotificationPreferences(userId);

      // 템플릿 처리
      final processedContent = _processTemplate(template, templateData);
      final personalizedContent = _personalizeContent(processedContent, userPreferences);

      // 오버라이드 데이터 적용
      final finalTitle = overrideData['title'] ?? personalizedContent['title'];
      final finalBody = overrideData['body'] ?? personalizedContent['body'];
      final finalChannels = overrideData['channels'] ?? personalizedContent['channels'];

      return await sendNotification(
        userId: userId,
        title: finalTitle,
        body: finalBody,
        type: NotificationType.values.firstWhere(
          (type) => type.name == template['type'],
          orElse: () => NotificationType.custom,
        ),
        priority: NotificationPriority.values.firstWhere(
          (priority) => priority.name == template['priority'],
          orElse: () => NotificationPriority.normal,
        ),
        channels: (finalChannels as List<dynamic>).map(
          (channel) => NotificationChannel.values.firstWhere(
            (c) => c.name == channel,
            orElse: () => NotificationChannel.push,
          ),
        ).toList(),
        data: {
          ...templateData,
          'templateId': templateId,
          'personalized': true,
        },
      );
    } catch (e) {
      throw NotificationException('Failed to send personalized notification: $e');
    }
  }

  // 벌크 알림 발송
  Future<BulkNotificationResult> sendBulkNotifications({
    required List<String> userIds,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic> data = const {},
    List<NotificationChannel> channels = const [NotificationChannel.push],
  }) async {
    final result = BulkNotificationResult();

    try {
      for (final userId in userIds) {
        try {
          final notificationId = await sendNotification(
            userId: userId,
            title: title,
            body: body,
            type: type,
            data: data,
            channels: channels,
          );

          result.successful.add(userId);
          result.notificationIds[userId] = notificationId;
        } catch (e) {
          result.failed.add(userId);
          result.errors[userId] = e.toString();
        }
      }

      return result;
    } catch (e) {
      throw NotificationException('Bulk notification failed: $e');
    }
  }

  // 알림 읽음 처리
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': Timestamp.now(),
      });

      // 알림 스트림 업데이트
      _notificationStream?.add(NotificationMessage(
        id: notificationId,
        userId: userId,
        title: '',
        body: '',
        type: NotificationType.systemAlert,
        priority: NotificationPriority.low,
        isRead: true,
        createdAt: Timestamp.now(),
      ));
    } catch (e) {
      throw NotificationException('Failed to mark notification as read: $e');
    }
  }

  // 알림 목록 조회
  Future<List<NotificationMessage>> getNotifications({
    required String userId,
    int limit = 20,
    int offset = 0,
    bool unreadOnly = false,
    NotificationType? type,
  }) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('createdAt', descending: true);

      if (unreadOnly) {
        query = query.where('isRead', isEqualTo: false);
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      final snapshot = await query.limit(limit).offset(offset).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return NotificationMessage(
          id: doc.id,
          userId: userId,
          title: data['title'] ?? '',
          body: data['body'] ?? '',
          type: NotificationType.values.firstWhere(
            (t) => t.name == data['type'],
            orElse: () => NotificationType.custom,
          ),
          priority: NotificationPriority.values.firstWhere(
            (p) => p.name == data['priority'],
            orElse: () => NotificationPriority.normal,
          ),
          data: data['data'] as Map<String, dynamic>? ?? {},
          channels: (data['channels'] as List<dynamic>?)
              ?.map((c) => NotificationChannel.values.firstWhere(
                    (channel) => channel.name == c,
                    orElse: () => NotificationChannel.push,
                  ))
              .toList() ?? [],
          isRead: data['isRead'] ?? false,
          createdAt: data['createdAt'] as Timestamp,
          scheduledFor: data['scheduledFor'] as Timestamp?,
          expiresAt: data['expiresAt'] as Timestamp?,
          imageUrl: data['imageUrl'],
          actions: (data['actions'] as List<dynamic>?)
              ?.map((a) => NotificationAction(
                    id: a['id'],
                    title: a['title'],
                    url: a['url'],
                    parameters: a['parameters'],
                  ))
              .toList() ?? [],
        );
      }).toList();
    } catch (e) {
      throw NotificationException('Failed to get notifications: $e');
    }
  }

  // 리마인더 규칙 관리
  Future<String> createReminderRule({
    required String userId,
    required String name,
    required String description,
    required String triggerType,
    required Map<String, dynamic> triggerConfig,
    required String template,
    List<NotificationChannel> channels = const [NotificationChannel.push],
  }) async {
    try {
      final ruleId = _generateId();

      final rule = ReminderRule(
        id: ruleId,
        name: name,
        description: description,
        triggerType: triggerType,
        triggerConfig: triggerConfig,
        channels: channels,
        template: template,
        createdBy: userId,
        createdAt: Timestamp.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reminder_rules')
          .doc(ruleId)
          .set({
        'name': rule.name,
        'description': rule.description,
        'triggerType': rule.triggerType,
        'triggerConfig': rule.triggerConfig,
        'channels': rule.channels.map((c) => c.name).toList(),
        'template': rule.template,
        'isActive': rule.isActive,
        'createdBy': rule.createdBy,
        'createdAt': rule.createdAt,
      });

      return ruleId;
    } catch (e) {
      throw NotificationException('Failed to create reminder rule: $e');
    }
  }

  // 알림 스트림
  Stream<NotificationMessage> getNotificationStream(String userId) {
    if (_notificationStream == null) {
      _notificationStream = StreamController<NotificationMessage>.broadcast();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              final notification = NotificationMessage(
                id: change.doc.id,
                userId: userId,
                title: data['title'] ?? '',
                body: data['body'] ?? '',
                type: NotificationType.values.firstWhere(
                  (t) => t.name == data['type'],
                  orElse: () => NotificationType.custom,
                ),
                priority: NotificationPriority.values.firstWhere(
                  (p) => p.name == data['priority'],
                  orElse: () => NotificationPriority.normal,
                ),
                data: data['data'] as Map<String, dynamic>? ?? {},
                isRead: data['isRead'] ?? false,
                createdAt: data['createdAt'] as Timestamp,
              );

              _notificationStream?.add(notification);
            }
          }
          return null as NotificationMessage;
        })
        .where((event) => event != null)
        .cast<NotificationMessage>();
  }

  // --- Private Helper Methods ---

  Future<void> _saveNotification(NotificationMessage notification) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(notification.userId)
        .collection('notifications')
        .doc(notification.id)
        .set({
        'title': notification.title,
        'body': notification.body,
        'type': notification.type.name,
        'priority': notification.priority.name,
        'data': notification.data,
        'channels': notification.channels.map((c) => c.name).toList(),
        'isRead': notification.isRead,
        'createdAt': notification.createdAt,
        'scheduledFor': notification.scheduledFor,
        'expiresAt': notification.expiresAt,
        'imageUrl': notification.imageUrl,
        'actions': notification.actions.map((a) => {
          'id': a.id,
          'title': a.title,
          'url': a.url,
          'parameters': a.parameters,
        }).toList(),
      });
  }

  Future<void> _deliverNotification(NotificationMessage notification) async {
    for (final channel in notification.channels) {
      switch (channel) {
        case NotificationChannel.push:
          await _sendPushNotification(notification);
          break;
        case NotificationChannel.email:
          await _sendEmailNotification(notification);
          break;
        case NotificationChannel.sms:
          await _sendSMSNotification(notification);
          break;
        case NotificationChannel.inApp:
          await _sendInAppNotification(notification);
          break;
        case NotificationChannel.webhook:
          await _sendWebhookNotification(notification);
          break;
      }
    }
  }

  Future<void> _sendPushNotification(NotificationMessage notification) async {
    final androidDetails = AndroidNotificationDetails(
      'grant_scout_notifications',
      'GrantScout',
      channelDescription: 'GrantScout notifications',
      importance: _getAndroidImportance(notification.priority),
      priority: _getAndroidPriority(notification.priority),
      color: 0xFF6366F1,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.id.hashCode,
      notification.title,
      notification.body,
      details,
      payload: notification.id,
    );
  }

  Future<void> _sendEmailNotification(NotificationMessage notification) async {
    // 이메일 발송 로직 (SendGrid, AWS SES 등)
  }

  Future<void> _sendSMSNotification(NotificationMessage notification) async {
    // SMS 발송 로직 (Twilio 등)
  }

  Future<void> _sendInAppNotification(NotificationMessage notification) async {
    // 인앱 알림은 스트림을 통해 자동 처리됨
  }

  Future<void> _sendWebhookNotification(NotificationMessage notification) async {
    // 웹훅 발송 로직
  }

  void _startScheduledNotificationProcessor() {
    // 1분마다 예약 알림 확인
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _processScheduledNotifications();
    });
  }

  Future<void> _processScheduledNotifications() async {
    try {
      final now = Timestamp.now();

      // 만료된 알림 정리
      await _cleanupExpiredNotifications(now);

      // 발송할 알림 조회
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('notifications')
          .where('scheduledFor', isLessThanOrEqualTo: now)
          .where('isRead', isEqualTo: false)
          .limit(100)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = doc.reference.parent.parent!.id;

        final notification = NotificationMessage(
          id: doc.id,
          userId: userId,
          title: data['title'] ?? '',
          body: data['body'] ?? '',
          type: NotificationType.values.firstWhere(
            (t) => t.name == data['type'],
            orElse: () => NotificationType.custom,
          ),
          priority: NotificationPriority.values.firstWhere(
            (p) => p.name == data['priority'],
            orElse: () => NotificationPriority.normal,
          ),
          data: data['data'] as Map<String, dynamic>? ?? {},
          channels: (data['channels'] as List<dynamic>?)
              ?.map((c) => NotificationChannel.values.firstWhere(
                    (channel) => channel.name == c,
                    orElse: () => NotificationChannel.push,
                  ))
              .toList() ?? [],
          isRead: false,
          createdAt: data['createdAt'] as Timestamp,
          scheduledFor: data['scheduledFor'] as Timestamp,
          expiresAt: data['expiresAt'] as Timestamp,
        );

        await _deliverNotification(notification);
      }
    } catch (e) {
      print('Failed to process scheduled notifications: $e');
    }
  }

  void _startReminderProcessor() {
    // 1시간마다 리마인더 규칙 처리
    _reminderTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      await _processReminderRules();
    });
  }

  Future<void> _processReminderRules() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('reminder_rules')
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final rule = ReminderRule(
          id: doc.id,
          name: doc['name'],
          description: doc['description'],
          triggerType: doc['triggerType'],
          triggerConfig: doc['triggerConfig'],
          channels: (doc['channels'] as List<dynamic>?)
              ?.map((c) => NotificationChannel.values.firstWhere(
                    (channel) => channel.name == c,
                    orElse: () => NotificationChannel.push,
                  ))
              .toList() ?? [],
          template: doc['template'],
          createdBy: doc['createdBy'],
          createdAt: doc['createdAt'] as Timestamp,
        );

        await _evaluateReminderRule(rule);
      }
    } catch (e) {
      print('Failed to process reminder rules: $e');
    }
  }

  Future<void> _evaluateReminderRule(ReminderRule rule) async {
    // 리마인더 규칙 평가 로직
    switch (rule.triggerType) {
      case 'deadline':
        await _evaluateDeadlineReminder(rule);
        break;
      case 'recurring':
        await _evaluateRecurringReminder(rule);
        break;
      // 다른 트리거 타입들...
    }
  }

  // 기타 헬퍼 메서드들...
  String _generateNotificationId() {
    return 'notif_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  AndroidImportance _getAndroidImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return AndroidImportance.low;
      case NotificationPriority.normal:
        return AndroidImportance.defaultImportance;
      case NotificationPriority.high:
        return AndroidImportance.high;
      case NotificationPriority.urgent:
        return AndroidImportance.max;
    }
  }

  AndroidPriority _getAndroidPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return AndroidPriority.low;
      case NotificationPriority.normal:
        return AndroidPriority.defaultPriority;
      case NotificationPriority.high:
        return AndroidPriority.high;
      case NotificationPriority.urgent:
        return AndroidPriority.max;
    }
  }

  Future<void> _cleanupExpiredNotifications(Timestamp now) async {
    await FirebaseFirestore.instance
        .collectionGroup('notifications')
        .where('expiresAt', isLessThan: now)
        .where('isRead', isEqualTo: false)
        .get()
        .then((snapshot) {
      for (final doc in snapshot.docs) {
        doc.reference.delete();
      }
    });
  }

  Future<Map<String, dynamic>?> _getNotificationTemplate(String templateId) async {
    final doc = await FirebaseFirestore.instance
        .collection('notification_templates')
        .doc(templateId)
        .get();

    return doc.exists ? doc.data() as Map<String, dynamic> : null;
  }

  Future<Map<String, dynamic>> _getUserNotificationPreferences(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('preferences')
        .doc('notifications')
        .get();

    return doc.exists ? doc.data() as Map<String, dynamic> : {};
  }

  Map<String, dynamic> _processTemplate(Map<String, dynamic> template, Map<String, dynamic> data) {
    // 템플릿 처리 로직 (변수 치환 등)
    return {
      'title': _replaceVariables(template['title'] ?? '', data),
      'body': _replaceVariables(template['body'] ?? '', data),
      'channels': template['channels'] ?? ['push'],
      'type': template['type'] ?? 'custom',
      'priority': template['priority'] ?? 'normal',
    };
  }

  String _replaceVariables(String text, Map<String, dynamic> data) {
    String result = text;
    data.forEach((key, value) {
      result = result.replaceAll('{$key}', value.toString());
    });
    return result;
  }

  Map<String, dynamic> _personalizeContent(Map<String, dynamic> content, Map<String, dynamic> preferences) {
    // 개인화 로직
    return content;
  }

  // 나머지 메서드들도 유사하게 구현...
  Future<void> _evaluateDeadlineReminder(ReminderRule rule) async {}
  Future<void> _evaluateRecurringReminder(ReminderRule rule) async {}
}

class BulkNotificationResult {
  final List<String> successful = [];
  final List<String> failed = [];
  final Map<String, String> notificationIds = {};
  final Map<String, String> errors = {};
}

class NotificationException implements Exception {
  final String message;
  NotificationException(this.message);

  @override
  String toString() => 'NotificationException: $message';
}