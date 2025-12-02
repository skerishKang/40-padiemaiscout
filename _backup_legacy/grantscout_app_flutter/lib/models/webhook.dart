import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

enum WebhookEventType {
  fileUploaded('파일 업로드됨'),
  fileAnalyzed('파일 분석 완료'),
  grantMatched('지원사업 매칭됨'),
  workflowStarted('워크플로우 시작됨'),
  workflowCompleted('워크플로우 완료됨'),
  teamMemberJoined('팀원 참여'),
  projectCreated('프로젝트 생성됨'),
  deadlineApproaching('마감일 임박'),
  custom('사용자 정의');

  const WebhookEventType(this.displayName);
  final String displayName;
}

enum WebhookStatus {
  active('활성'),
  inactive('비활성'),
  failed('실패'),
  paused('일시 중지');

  const WebhookStatus(this.displayName);
  final String displayName;
}

enum HttpMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  patch('PATCH'),
  delete('DELETE');

  const HttpMethod(this.displayName);
  final String displayName;
}

class Webhook {
  final String id;
  final String name;
  final String description;
  final String url;
  final HttpMethod method;
  final Map<String, String> headers;
  final Map<String, dynamic> payload;
  final List<WebhookEventType> events;
  final WebhookStatus status;
  final String? secretKey; // 보안을 위한 시크릿 키
  final int retryCount;
  final int timeout; // 초 단위
  final bool isActive;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final List<WebhookLog> logs;

  const Webhook({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
    required this.method,
    this.headers = const {},
    this.payload = const {},
    required this.events,
    required this.status,
    this.secretKey,
    this.retryCount = 3,
    this.timeout = 30,
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.logs = const [],
  });

  factory Webhook.fromMap(Map<String, dynamic> map, String id) {
    return Webhook(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      url: map['url'] ?? '',
      method: HttpMethod.values.firstWhere(
        (method) => method.name == map['method'],
        orElse: () => HttpMethod.post,
      ),
      headers: Map<String, String>.from(map['headers'] ?? {}),
      payload: map['payload'] as Map<String, dynamic>? ?? {},
      events: (map['events'] as List<dynamic>?)
          ?.map((event) => WebhookEventType.values.firstWhere(
                (type) => type.name == event,
                orElse: () => WebhookEventType.custom,
              ))
          .toList() ?? [],
      status: WebhookStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => WebhookStatus.inactive,
      ),
      secretKey: map['secretKey'],
      retryCount: map['retryCount'] ?? 3,
      timeout: map['timeout'] ?? 30,
      isActive: map['isActive'] ?? true,
      createdBy: map['createdBy'] ?? '',
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: map['updatedAt'] as Timestamp? ?? Timestamp.now(),
      logs: (map['logs'] as List<dynamic>?)
          ?.map((log) => WebhookLog.fromMap(log as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'url': url,
      'method': method.name,
      'headers': headers,
      'payload': payload,
      'events': events.map((event) => event.name).toList(),
      'status': status.name,
      'secretKey': secretKey,
      'retryCount': retryCount,
      'timeout': timeout,
      'isActive': isActive,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'logs': logs.map((log) => log.toMap()).toList(),
    };
  }
}

class WebhookLog {
  final String id;
  final String webhookId;
  final WebhookEventType eventType;
  final Map<String, dynamic> payload;
  final int statusCode;
  final String response;
  final String? error;
  final Duration duration;
  final Timestamp createdAt;
  final Map<String, String> requestHeaders;
  final Map<String, String> responseHeaders;

  const WebhookLog({
    required this.id,
    required this.webhookId,
    required this.eventType,
    required this.payload,
    required this.statusCode,
    required this.response,
    this.error,
    required this.duration,
    required this.createdAt,
    this.requestHeaders = const {},
    this.responseHeaders = const {},
  });

  factory WebhookLog.fromMap(Map<String, dynamic> map) {
    return WebhookLog(
      id: map['id'] ?? '',
      webhookId: map['webhookId'] ?? '',
      eventType: WebhookEventType.values.firstWhere(
        (type) => type.name == map['eventType'],
        orElse: () => WebhookEventType.custom,
      ),
      payload: map['payload'] as Map<String, dynamic>? ?? {},
      statusCode: map['statusCode'] ?? 0,
      response: map['response'] ?? '',
      error: map['error'],
      duration: Duration(milliseconds: map['duration'] ?? 0),
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      requestHeaders: Map<String, String>.from(map['requestHeaders'] ?? {}),
      responseHeaders: Map<String, String>.from(map['responseHeaders'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'webhookId': webhookId,
      'eventType': eventType.name,
      'payload': payload,
      'statusCode': statusCode,
      'response': response,
      'error': error,
      'duration': duration.inMilliseconds,
      'createdAt': createdAt,
      'requestHeaders': requestHeaders,
      'responseHeaders': responseHeaders,
    };
  }

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

class ApiIntegration {
  final String id;
  final String name;
  final String description;
  final String baseUrl;
  final String? apiKey;
  final Map<String, String> defaultHeaders;
  final List<ApiEndpoint> endpoints;
  final bool isActive;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final Map<String, dynamic> configuration;

  const ApiIntegration({
    required this.id,
    required this.name,
    required this.description,
    required this.baseUrl,
    this.apiKey,
    this.defaultHeaders = const {},
    this.endpoints = const [],
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.configuration = const {},
  });

  factory ApiIntegration.fromMap(Map<String, dynamic> map, String id) {
    return ApiIntegration(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      baseUrl: map['baseUrl'] ?? '',
      apiKey: map['apiKey'],
      defaultHeaders: Map<String, String>.from(map['defaultHeaders'] ?? {}),
      endpoints: (map['endpoints'] as List<dynamic>?)
          ?.map((endpoint) => ApiEndpoint.fromMap(endpoint as Map<String, dynamic>))
          .toList() ?? [],
      isActive: map['isActive'] ?? true,
      createdBy: map['createdBy'] ?? '',
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: map['updatedAt'] as Timestamp? ?? Timestamp.now(),
      configuration: map['configuration'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'defaultHeaders': defaultHeaders,
      'endpoints': endpoints.map((endpoint) => endpoint.toMap()).toList(),
      'isActive': isActive,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'configuration': configuration,
    };
  }
}

class ApiEndpoint {
  final String id;
  final String name;
  final String description;
  final String path;
  final HttpMethod method;
  final Map<String, dynamic> parameters;
  final Map<String, String> headers;
  final Map<String, dynamic> requestBody;
  final List<WebhookEventType> triggers;

  const ApiEndpoint({
    required this.id,
    required this.name,
    required this.description,
    required this.path,
    required this.method,
    this.parameters = const {},
    this.headers = const {},
    this.requestBody = const {},
    this.triggers = const [],
  });

  factory ApiEndpoint.fromMap(Map<String, dynamic> map) {
    return ApiEndpoint(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      path: map['path'] ?? '',
      method: HttpMethod.values.firstWhere(
        (method) => method.name == map['method'],
        orElse: () => HttpMethod.get,
      ),
      parameters: map['parameters'] as Map<String, dynamic>? ?? {},
      headers: Map<String, String>.from(map['headers'] ?? {}),
      requestBody: map['requestBody'] as Map<String, dynamic>? ?? {},
      triggers: (map['triggers'] as List<dynamic>?)
          ?.map((trigger) => WebhookEventType.values.firstWhere(
                (type) => type.name == trigger,
                orElse: () => WebhookEventType.custom,
              ))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'path': path,
      'method': method.name,
      'parameters': parameters,
      'headers': headers,
      'requestBody': requestBody,
      'triggers': triggers.map((trigger) => trigger.name).toList(),
    };
  }

  String getFullUrl(String baseUrl) {
    return '$baseUrl$path';
  }
}

// 사전 정의된 API 통합 템플릿
class PredefinedIntegrations {
  static ApiIntegration get slackIntegration {
    return ApiIntegration(
      id: 'slack',
      name: 'Slack 연동',
      description: 'Slack 채널에 지원사업 알림을 발송합니다.',
      baseUrl: 'https://hooks.slack.com',
      apiKey: null, // Slack은 웹훅 URL 사용
      defaultHeaders: {
        'Content-Type': 'application/json',
      },
      endpoints: [
        ApiEndpoint(
          id: 'send_message',
          name: '메시지 발송',
          description: 'Slack 채널에 메시지를 발송합니다.',
          path: '/services/{workspace_id}/{channel_id}/{webhook_token}',
          method: HttpMethod.post,
          requestBody: {
            'text': 'GrantScout 알림: {{message}}',
            'attachments': [
              {
                'color': '#36a64f',
                'fields': [
                  {
                    'title': '지원사업',
                    'value': '{{grant_title}}',
                    'short': true,
                  },
                  {
                    'title': '마감일',
                    'value': '{{deadline}}',
                    'short': true,
                  },
                ],
              },
            ],
          },
          triggers: [
            WebhookEventType.grantMatched,
            WebhookEventType.deadlineApproaching,
          ],
        ),
      ],
      isActive: false,
      createdBy: 'system',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      configuration: {
        'workspace_id': '',
        'channel_id': '',
        'webhook_token': '',
      },
    );
  }

  static ApiIntegration get teamsIntegration {
    return ApiIntegration(
      id: 'microsoft_teams',
      name: 'Microsoft Teams 연동',
      description: 'Microsoft Teams에 지원사업 알림을 발송합니다.',
      baseUrl: 'https://outlook.office.com/webhook',
      apiKey: null,
      defaultHeaders: {
        'Content-Type': 'application/json',
      },
      endpoints: [
        ApiEndpoint(
          id: 'send_card',
          name: '카드 발송',
          description: 'Teams에 AdaptiveCard 형식으로 알림을 발송합니다.',
          path: '/{webhook_id}',
          method: HttpMethod.post,
          requestBody: {
            'type': 'message',
            'attachments': [
              {
                'contentType': 'application/vnd.microsoft.card.adaptive',
                'content': {
                  'type': 'AdaptiveCard',
                  'version': '1.0',
                  'body': [
                    {
                      'type': 'TextBlock',
                      'text': 'GrantScout 지원사업 알림',
                      'weight': 'Bolder',
                      'size': 'Medium',
                    },
                    {
                      'type': 'FactSet',
                      'facts': [
                        {'title': '제목', 'value': '{{grant_title}}'},
                        {'title': '마감일', 'value': '{{deadline}}'},
                        {'title': '적합도', 'value': '{{suitability_score}}%'},
                      ],
                    },
                  ],
                },
              },
            ],
          },
          triggers: [
            WebhookEventType.grantMatched,
            WebhookEventType.deadlineApproaching,
          ],
        ),
      ],
      isActive: false,
      createdBy: 'system',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      configuration: {
        'webhook_id': '',
      },
    );
  }

  static ApiIntegration get googleSheetsIntegration {
    return ApiIntegration(
      id: 'google_sheets',
      name: 'Google Sheets 연동',
      description: '지원사업 정보를 Google Sheets에 자동으로 기록합니다.',
      baseUrl: 'https://sheets.googleapis.com/v4/spreadsheets',
      apiKey: null, // OAuth 사용
      defaultHeaders: {
        'Content-Type': 'application/json',
      },
      endpoints: [
        ApiEndpoint(
          id: 'append_values',
          name: '행 추가',
          description: '시트에 새로운 행을 추가합니다.',
          path: '/{spreadsheet_id}/values/{sheet_name}!A:Z:append',
          method: HttpMethod.post,
          requestBody: {
            'values': [
              [
                '{{timestamp}}',
                '{{grant_title}}',
                '{{agency}}',
                '{{deadline}}',
                '{{suitability_score}}',
                '{{status}}',
              ],
            ],
          },
          triggers: [
            WebhookEventType.grantMatched,
          ],
        ),
      ],
      isActive: false,
      createdBy: 'system',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      configuration: {
        'spreadsheet_id': '',
        'sheet_name': '지원사업',
        'oauth_token': '',
      },
    );
  }

  static List<ApiIntegration> get allIntegrations => [
    slackIntegration,
    teamsIntegration,
    googleSheetsIntegration,
  ];
}

// 웹훅 페이로드 빌더
class WebhookPayloadBuilder {
  static Map<String, dynamic> buildPayload(
    WebhookEventType eventType,
    Map<String, dynamic> data,
  ) {
    final basePayload = {
      'event': eventType.name,
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0',
      'data': data,
    };

    switch (eventType) {
      case WebhookEventType.fileUploaded:
        return {
          ...basePayload,
          'file': {
            'id': data['fileId'],
            'name': data['fileName'],
            'size': data['fileSize'],
            'type': data['fileType'],
            'uploadedBy': data['uploadedBy'],
          },
        };

      case WebhookEventType.grantMatched:
        return {
          ...basePayload,
          'grant': {
            'id': data['grantId'],
            'title': data['title'],
            'agency': data['agency'],
            'deadline': data['deadline'],
            'suitabilityScore': data['suitabilityScore'],
            'matchReasons': data['matchReasons'],
          },
          'file': {
            'id': data['fileId'],
            'name': data['fileName'],
          },
        };

      case WebhookEventType.deadlineApproaching:
        return {
          ...basePayload,
          'grant': {
            'id': data['grantId'],
            'title': data['title'],
            'deadline': data['deadline'],
            'daysUntilDeadline': data['daysUntil'],
          },
          'user': {
            'id': data['userId'],
            'email': data['userEmail'],
          },
        };

      default:
        return basePayload;
    }
  }

  static String generateSignature(
    String payload,
    String secretKey,
  ) {
    final bytes = utf8.encode('$payload.$secretKey');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}