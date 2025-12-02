import 'package:cloud_firestore/cloud_firestore.dart';

enum WorkflowTriggerType {
  manual('수동 실행'),
  fileUpload('파일 업로드 시'),
  newGrant('신규 지원사업 발견 시'),
  deadlineApproaching('마감일 임박 시'),
  schedule('정기 실행'),
  webhook('웹훅 트리거');

  const WorkflowTriggerType(this.displayName);
  final String displayName;
}

enum WorkflowActionType {
  analyzeFile('파일 분석'),
  matchGrants('지원사업 매칭'),
  sendNotification('알림 발송'),
  createTask('작업 생성'),
  sendEmail('이메일 발송'),
  updateStatus('상태 업데이트'),
  callAPI('API 호출'),
  delay('지연'),
  condition('조건 분기'),
  loop('반복');

  const WorkflowActionType(this.displayName);
  final String displayName;
}

enum WorkflowStatus {
  draft('초안'),
  active('활성'),
  paused('일시 중지'),
  completed('완료'),
  failed('실패'),
  archived('보관');

  const WorkflowStatus(this.displayName);
  final String displayName;
}

class WorkflowTemplate {
  final String id;
  final String name;
  final String description;
  final List<WorkflowTrigger> triggers;
  final List<WorkflowAction> actions;
  final Map<String, dynamic> variables;
  final String createdBy;
  final bool isPublic;
  final String category;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const WorkflowTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.triggers,
    required this.actions,
    this.variables = const {},
    required this.createdBy,
    this.isPublic = false,
    this.category = 'general',
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkflowTemplate.fromMap(Map<String, dynamic> map, String id) {
    return WorkflowTemplate(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      triggers: (map['triggers'] as List<dynamic>?)
          ?.map((trigger) => WorkflowTrigger.fromMap(trigger as Map<String, dynamic>))
          .toList() ?? [],
      actions: (map['actions'] as List<dynamic>?)
          ?.map((action) => WorkflowAction.fromMap(action as Map<String, dynamic>))
          .toList() ?? [],
      variables: map['variables'] as Map<String, dynamic>? ?? {},
      createdBy: map['createdBy'] ?? '',
      isPublic: map['isPublic'] ?? false,
      category: map['category'] ?? 'general',
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: map['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'triggers': triggers.map((trigger) => trigger.toMap()).toList(),
      'actions': actions.map((action) => action.toMap()).toList(),
      'variables': variables,
      'createdBy': createdBy,
      'isPublic': isPublic,
      'category': category,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class WorkflowTrigger {
  final String id;
  final WorkflowTriggerType type;
  final Map<String, dynamic> config;
  final bool isEnabled;

  const WorkflowTrigger({
    required this.id,
    required this.type,
    required this.config,
    this.isEnabled = true,
  });

  factory WorkflowTrigger.fromMap(Map<String, dynamic> map) {
    return WorkflowTrigger(
      id: map['id'] ?? '',
      type: WorkflowTriggerType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => WorkflowTriggerType.manual,
      ),
      config: map['config'] as Map<String, dynamic>? ?? {},
      isEnabled: map['isEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'config': config,
      'isEnabled': isEnabled,
    };
  }
}

class WorkflowAction {
  final String id;
  final WorkflowActionType type;
  final Map<String, dynamic> config;
  final List<String> nextActions; // 다음 액션 ID 목록
  final String? condition; // 실행 조건

  const WorkflowAction({
    required this.id,
    required this.type,
    required this.config,
    this.nextActions = const [],
    this.condition,
  });

  factory WorkflowAction.fromMap(Map<String, dynamic> map) {
    return WorkflowAction(
      id: map['id'] ?? '',
      type: WorkflowActionType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => WorkflowActionType.delay,
      ),
      config: map['config'] as Map<String, dynamic>? ?? {},
      nextActions: List<String>.from(map['nextActions'] ?? []),
      condition: map['condition'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'config': config,
      'nextActions': nextActions,
      'condition': condition,
    };
  }
}

class WorkflowExecution {
  final String id;
  final String templateId;
  final String userId;
  final WorkflowStatus status;
  final Map<String, dynamic> context;
  final List<WorkflowExecutionStep> steps;
  final String? error;
  final Timestamp startedAt;
  final Timestamp? completedAt;
  final Map<String, dynamic> result;

  const WorkflowExecution({
    required this.id,
    required this.templateId,
    required this.userId,
    required this.status,
    this.context = const {},
    this.steps = const [],
    this.error,
    required this.startedAt,
    this.completedAt,
    this.result = const {},
  });

  factory WorkflowExecution.fromMap(Map<String, dynamic> map, String id) {
    return WorkflowExecution(
      id: id,
      templateId: map['templateId'] ?? '',
      userId: map['userId'] ?? '',
      status: WorkflowStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => WorkflowStatus.draft,
      ),
      context: map['context'] as Map<String, dynamic>? ?? {},
      steps: (map['steps'] as List<dynamic>?)
          ?.map((step) => WorkflowExecutionStep.fromMap(step as Map<String, dynamic>))
          .toList() ?? [],
      error: map['error'],
      startedAt: map['startedAt'] as Timestamp? ?? Timestamp.now(),
      completedAt: map['completedAt'] as Timestamp?,
      result: map['result'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'templateId': templateId,
      'userId': userId,
      'status': status.name,
      'context': context,
      'steps': steps.map((step) => step.toMap()).toList(),
      'error': error,
      'startedAt': startedAt,
      'completedAt': completedAt,
      'result': result,
    };
  }
}

class WorkflowExecutionStep {
  final String id;
  final String actionId;
  final WorkflowActionType actionType;
  final String status; // pending, running, completed, failed
  final Map<String, dynamic> input;
  final Map<String, dynamic> output;
  final String? error;
  final Timestamp startedAt;
  final Timestamp? completedAt;

  const WorkflowExecutionStep({
    required this.id,
    required this.actionId,
    required this.actionType,
    required this.status,
    this.input = const {},
    this.output = const {},
    this.error,
    required this.startedAt,
    this.completedAt,
  });

  factory WorkflowExecutionStep.fromMap(Map<String, dynamic> map) {
    return WorkflowExecutionStep(
      id: map['id'] ?? '',
      actionId: map['actionId'] ?? '',
      actionType: WorkflowActionType.values.firstWhere(
        (type) => type.name == map['actionType'],
        orElse: () => WorkflowActionType.delay,
      ),
      status: map['status'] ?? 'pending',
      input: map['input'] as Map<String, dynamic>? ?? {},
      output: map['output'] as Map<String, dynamic>? ?? {},
      error: map['error'],
      startedAt: map['startedAt'] as Timestamp? ?? Timestamp.now(),
      completedAt: map['completedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'actionId': actionId,
      'actionType': actionType.name,
      'status': status,
      'input': input,
      'output': output,
      'error': error,
      'startedAt': startedAt,
      'completedAt': completedAt,
    };
  }
}

// 사전 정의된 워크플로우 템플릿
class PredefinedWorkflows {
  static WorkflowTemplate get smartGrantMatching {
    return WorkflowTemplate(
      id: 'smart_grant_matching',
      name: '스마트 지원사업 매칭',
      description: '파일 업로드 시 자동으로 적합한 지원사업을 찾아 알림을 발송합니다.',
      triggers: [
        WorkflowTrigger(
          id: 'file_upload_trigger',
          type: WorkflowTriggerType.fileUpload,
          config: {
            'fileTypes': ['pdf', 'doc', 'docx'],
            'categories': ['business_plan', 'proposal', 'report'],
          },
        ),
      ],
      actions: [
        WorkflowAction(
          id: 'analyze_file',
          type: WorkflowActionType.analyzeFile,
          config: {
            'model': 'gemini-pro',
            'extractKeywords': true,
            'analyzeIndustry': true,
          },
          nextActions: ['match_grants'],
        ),
        WorkflowAction(
          id: 'match_grants',
          type: WorkflowActionType.matchGrants,
          config: {
            'minSuitabilityScore': 70,
            'maxResults': 10,
          },
          nextActions: ['send_notification'],
        ),
        WorkflowAction(
          id: 'send_notification',
          type: WorkflowActionType.sendNotification,
          config: {
            'type': 'push',
            'title': '새로운 지원사업 매칭 결과',
            'template': 'grant_match_notification',
          },
        ),
      ],
      variables: {
        'user_keywords': [],
        'industry': '',
        'preferred_regions': [],
      },
      createdBy: 'system',
      isPublic: true,
      category: 'grant_matching',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
  }

  static WorkflowTemplate get deadlineReminder {
    return WorkflowTemplate(
      id: 'deadline_reminder',
      name: '마감일 알림',
      description: '지원사업 마감일이 임박하면 자동으로 알림을 발송합니다.',
      triggers: [
        WorkflowTrigger(
          id: 'deadline_trigger',
          type: WorkflowTriggerType.deadlineApproaching,
          config: {
            'daysBefore': [7, 3, 1],
            'includeHourly': true, // 마감일 24시간 전에는 시간 단위 알림
          },
        ),
      ],
      actions: [
        WorkflowAction(
          id: 'check_deadline',
          type: WorkflowActionType.condition,
          config: {
            'condition': 'days_until_deadline <= 1',
          },
          nextActions: ['urgent_notification', 'regular_notification'],
        ),
        WorkflowAction(
          id: 'urgent_notification',
          type: WorkflowActionType.sendNotification,
          config: {
            'type': 'push',
            'priority': 'high',
            'title': '긴급: 지원사업 마감 임박',
            'template': 'urgent_deadline_notification',
          },
        ),
        WorkflowAction(
          id: 'regular_notification',
          type: WorkflowActionType.sendNotification,
          config: {
            'type': 'push',
            'priority': 'normal',
            'title': '지원사업 마감일 알림',
            'template': 'deadline_notification',
          },
        ),
      ],
      variables: {
        'notification_channels': ['push', 'email'],
        'quiet_hours': {'start': 22, 'end': 8},
      },
      createdBy: 'system',
      isPublic: true,
      category: 'deadline_management',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
  }

  static WorkflowTemplate get weeklyReport {
    return WorkflowTemplate(
      id: 'weekly_report',
      name: '주간 활동 보고서',
      description: '매주 지원사업 탐색 활동과 결과를 요약한 보고서를 자동 생성합니다.',
      triggers: [
        WorkflowTrigger(
          id: 'weekly_trigger',
          type: WorkflowTriggerType.schedule,
          config: {
            'cron': '0 9 * * 1', // 매주 월요일 오전 9시
            'timezone': 'Asia/Seoul',
          },
        ),
      ],
      actions: [
        WorkflowAction(
          id: 'collect_weekly_data',
          type: WorkflowActionType.callAPI,
          config: {
            'endpoint': '/api/analytics/weekly',
            'method': 'GET',
          },
          nextActions: ['generate_report'],
        ),
        WorkflowAction(
          id: 'generate_report',
          type: WorkflowActionType.callAPI,
          config: {
            'endpoint': '/api/reports/generate',
            'method': 'POST',
            'template': 'weekly_activity_report',
          },
          nextActions: ['send_email'],
        ),
        WorkflowAction(
          id: 'send_email',
          type: WorkflowActionType.sendEmail,
          config: {
            'template': 'weekly_report_email',
            'includeCharts': true,
          },
        ),
      ],
      variables: {
        'report_format': 'pdf',
        'recipients': ['user_email'],
        'include_insights': true,
      },
      createdBy: 'system',
      isPublic: true,
      category: 'reporting',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
  }

  static List<WorkflowTemplate> get allTemplates => [
    smartGrantMatching,
    deadlineReminder,
    weeklyReport,
  ];
}