import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType {
  grantAnalysis('지원사업 분석 보고서'),
  suitabilityReport('적합성 평가 보고서'),
  weeklyActivity('주간 활동 보고서'),
  monthlySummary('월간 요약 보고서'),
  customAnalysis('사용자 정의 분석'),
  comparison('비교 분석 보고서'),
  recommendations('추천 보고서');

  const ReportType(this.displayName);
  final String displayName;
}

enum ReportFormat {
  pdf('PDF'),
  docx('Word 문서'),
  html('HTML'),
  json('JSON 데이터'),
  excel('Excel');

  const ReportFormat(this.displayName);
  final String displayName;
}

enum ReportStatus {
  generating('생성 중'),
  completed('완료됨'),
  failed('실패함'),
  scheduled('예약됨');

  const ReportStatus(this.displayName);
  final String displayName;
}

class ReportTemplate {
  final String id;
  final String name;
  final String description;
  final ReportType type;
  final Map<String, dynamic> configuration;
  final List<ReportSection> sections;
  final String? thumbnail;
  final bool isPublic;
  final String category;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const ReportTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.configuration,
    required this.sections,
    this.thumbnail,
    this.isPublic = false,
    this.category = 'general',
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportTemplate.fromMap(Map<String, dynamic> map, String id) {
    return ReportTemplate(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      type: ReportType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => ReportType.customAnalysis,
      ),
      configuration: map['configuration'] as Map<String, dynamic>? ?? {},
      sections: (map['sections'] as List<dynamic>?)
          ?.map((section) => ReportSection.fromMap(section as Map<String, dynamic>))
          .toList() ?? [],
      thumbnail: map['thumbnail'],
      isPublic: map['isPublic'] ?? false,
      category: map['category'] ?? 'general',
      createdBy: map['createdBy'] ?? '',
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: map['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'type': type.name,
      'configuration': configuration,
      'sections': sections.map((section) => section.toMap()).toList(),
      'thumbnail': thumbnail,
      'isPublic': isPublic,
      'category': category,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class ReportSection {
  final String id;
  final String title;
  final String type; // 'summary', 'chart', 'table', 'text', 'recommendations'
  final Map<String, dynamic> configuration;
  final int order;
  final bool isVisible;

  const ReportSection({
    required this.id,
    required this.title,
    required this.type,
    required this.configuration,
    required this.order,
    this.isVisible = true,
  });

  factory ReportSection.fromMap(Map<String, dynamic> map) {
    return ReportSection(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      type: map['type'] ?? 'text',
      configuration: map['configuration'] as Map<String, dynamic>? ?? {},
      order: map['order'] ?? 0,
      isVisible: map['isVisible'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'configuration': configuration,
      'order': order,
      'isVisible': isVisible,
    };
  }
}

class GeneratedReport {
  final String id;
  final String templateId;
  final String title;
  final String description;
  final ReportType type;
  final ReportFormat format;
  final ReportStatus status;
  final Map<String, dynamic> data;
  final Map<String, dynamic> metadata;
  final String? filePath;
  final int? fileSize;
  final String? downloadUrl;
  final String createdBy;
  final List<String> recipients;
  final Timestamp createdAt;
  final Timestamp? completedAt;
  final Timestamp? expiresAt;
  final int downloadCount;
  final String? error;

  const GeneratedReport({
    required this.id,
    required this.templateId,
    required this.title,
    required this.description,
    required this.type,
    required this.format,
    required this.status,
    required this.data,
    this.metadata = const {},
    this.filePath,
    this.fileSize,
    this.downloadUrl,
    required this.createdBy,
    this.recipients = const [],
    required this.createdAt,
    this.completedAt,
    this.expiresAt,
    this.downloadCount = 0,
    this.error,
  });

  factory GeneratedReport.fromMap(Map<String, dynamic> map, String id) {
    return GeneratedReport(
      id: id,
      templateId: map['templateId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: ReportType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => ReportType.customAnalysis,
      ),
      format: ReportFormat.values.firstWhere(
        (format) => format.name == map['format'],
        orElse: () => ReportFormat.pdf,
      ),
      status: ReportStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => ReportStatus.generating,
      ),
      data: map['data'] as Map<String, dynamic>? ?? {},
      metadata: map['metadata'] as Map<String, dynamic>? ?? {},
      filePath: map['filePath'],
      fileSize: map['fileSize'],
      downloadUrl: map['downloadUrl'],
      createdBy: map['createdBy'] ?? '',
      recipients: List<String>.from(map['recipients'] ?? []),
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      completedAt: map['completedAt'] as Timestamp?,
      expiresAt: map['expiresAt'] as Timestamp?,
      downloadCount: map['downloadCount'] ?? 0,
      error: map['error'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'templateId': templateId,
      'title': title,
      'description': description,
      'type': type.name,
      'format': format.name,
      'status': status.name,
      'data': data,
      'metadata': metadata,
      'filePath': filePath,
      'fileSize': fileSize,
      'downloadUrl': downloadUrl,
      'createdBy': createdBy,
      'recipients': recipients,
      'createdAt': createdAt,
      'completedAt': completedAt,
      'expiresAt': expiresAt,
      'downloadCount': downloadCount,
      'error': error,
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!.toDate());
  }

  String get formattedFileSize {
    if (fileSize == null) return '알 수 없음';

    final size = fileSize!;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class ReportSchedule {
  final String id;
  final String templateId;
  final String name;
  final String description;
  final String cron; // Cron expression
  final List<String> recipients;
  final ReportFormat format;
  final Map<String, dynamic> parameters;
  final bool isActive;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp lastRun;
  final Timestamp? nextRun;

  const ReportSchedule({
    required this.id,
    required this.templateId,
    required this.name,
    required this.description,
    required this.cron,
    required this.recipients,
    required this.format,
    this.parameters = const {},
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    required this.lastRun,
    this.nextRun,
  });

  factory ReportSchedule.fromMap(Map<String, dynamic> map, String id) {
    return ReportSchedule(
      id: id,
      templateId: map['templateId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      cron: map['cron'] ?? '',
      recipients: List<String>.from(map['recipients'] ?? []),
      format: ReportFormat.values.firstWhere(
        (format) => format.name == map['format'],
        orElse: () => ReportFormat.pdf,
      ),
      parameters: map['parameters'] as Map<String, dynamic>? ?? {},
      isActive: map['isActive'] ?? true,
      createdBy: map['createdBy'] ?? '',
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      lastRun: map['lastRun'] as Timestamp? ?? Timestamp.now(),
      nextRun: map['nextRun'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'templateId': templateId,
      'name': name,
      'description': description,
      'cron': cron,
      'recipients': recipients,
      'format': format.name,
      'parameters': parameters,
      'isActive': isActive,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'lastRun': lastRun,
      'nextRun': nextRun,
    };
  }
}

// 사전 정의된 보고서 템플릿
class PredefinedReportTemplates {
  static ReportTemplate get comprehensiveAnalysis {
    return ReportTemplate(
      id: 'comprehensive_analysis',
      name: '종합 분석 보고서',
      description: '파일 분석, 지원사업 매칭, 적합성 평가를 포함한 종합 보고서',
      type: ReportType.grantAnalysis,
      configuration: {
        'includeCharts': true,
        'includeRecommendations': true,
        'language': 'ko',
        'branding': true,
      },
      sections: [
        ReportSection(
          id: 'executive_summary',
          title: '요약',
          type: 'summary',
          configuration: {
            'includeKeyFindings': true,
            'includeRecommendations': true,
            'maxWords': 300,
          },
          order: 1,
        ),
        ReportSection(
          id: 'file_analysis',
          title: '파일 분석 결과',
          type: 'table',
          configuration: {
            'includeMetrics': true,
            'includeKeywords': true,
            'includeIndustry': true,
          },
          order: 2,
        ),
        ReportSection(
          id: 'grant_matches',
          title: '매칭된 지원사업',
          type: 'table',
          configuration: {
            'sortBy': 'suitability_score',
            'limit': 20,
            'includeDetails': true,
          },
          order: 3,
        ),
        ReportSection(
          id: 'suitability_chart',
          title: '적합도 분석',
          type: 'chart',
          configuration: {
            'chartType': 'bar',
            'includeTrend': true,
          },
          order: 4,
        ),
        ReportSection(
          id: 'recommendations',
          title: '추천 사항',
          type: 'recommendations',
          configuration: {
            'includeActionItems': true,
            'includeTimeline': true,
          },
          order: 5,
        ),
      ],
      isPublic: true,
      category: 'analysis',
      createdBy: 'system',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
  }

  static ReportTemplate get weeklyActivity {
    return ReportTemplate(
      id: 'weekly_activity',
      name: '주간 활동 보고서',
      description: '지난 주간의 지원사업 탐색 활동과 결과를 요약한 보고서',
      type: ReportType.weeklyActivity,
      configuration: {
        'includeCharts': true,
        'includeTrends': true,
        'language': 'ko',
      },
      sections: [
        ReportSection(
          id: 'weekly_summary',
          title: '주간 요약',
          type: 'summary',
          configuration: {
            'includeMetrics': true,
            'includeHighlights': true,
          },
          order: 1,
        ),
        ReportSection(
          id: 'activity_trends',
          title: '활동 트렌드',
          type: 'chart',
          configuration: {
            'chartType': 'line',
            'period': 'week',
          },
          order: 2,
        ),
        ReportSection(
          id: 'new_opportunities',
          title: '새로운 기회',
          type: 'table',
          configuration: {
            'limit': 10,
            'sortBy': 'deadline',
          },
          order: 3,
        ),
        ReportSection(
          id: 'upcoming_deadlines',
          title: '임박한 마감일',
          type: 'table',
          configuration: {
            'daysAhead': 7,
            'sortBy': 'deadline',
          },
          order: 4,
        ),
      ],
      isPublic: true,
      category: 'activity',
      createdBy: 'system',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
  }

  static ReportTemplate get suitabilityEvaluation {
    return ReportTemplate(
      id: 'suitability_evaluation',
      name: '적합성 평가 보고서',
      description: '특정 지원사업에 대한 상세 적합성 평가 보고서',
      type: ReportType.suitabilityReport,
      configuration: {
        'includeScoreBreakdown': true,
        'includeImprovementTips': true,
        'includeComparison': true,
        'language': 'ko',
      },
      sections: [
        ReportSection(
          id: 'grant_overview',
          title: '지원사업 개요',
          type: 'text',
          configuration: {
            'includeRequirements': true,
            'includeEvaluationCriteria': true,
          },
          order: 1,
        ),
        ReportSection(
          id: 'suitability_score',
          title: '적합도 점수',
          type: 'chart',
          configuration: {
            'chartType': 'radar',
            'includeBreakdown': true,
          },
          order: 2,
        ),
        ReportSection(
          id: 'detailed_analysis',
          title: '상세 분석',
          type: 'table',
          configuration: {
            'includeCategories': true,
            'includeScores': true,
            'includeComments': true,
          },
          order: 3,
        ),
        ReportSection(
          id: 'strengths_weaknesses',
          title: '강점과 약점',
          type: 'text',
          configuration: {
            'includeActionable': true,
          },
          order: 4,
        ),
        ReportSection(
          id: 'improvement_recommendations',
          title: '개선 추천',
          type: 'recommendations',
          configuration: {
            'includePriorities': true,
            'includeTimeline': true,
          },
          order: 5,
        ),
      ],
      isPublic: true,
      category: 'evaluation',
      createdBy: 'system',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
  }

  static List<ReportTemplate> get allTemplates => [
    comprehensiveAnalysis,
    weeklyActivity,
    suitabilityEvaluation,
  ];
}