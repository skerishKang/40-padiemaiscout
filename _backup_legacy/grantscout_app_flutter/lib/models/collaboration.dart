import 'package:cloud_firestore/cloud_firestore.dart';

enum TeamRole {
  owner('소유자', '팀 관리 및 모든 권한'),
  admin('관리자', '팀원 관리 및 모든 작업 권한'),
  member('팀원', '파일 업로드 및 분석 권한'),
  viewer('뷰어', '조회 전용 권한');

  const TeamRole(this.displayName, this.description);
  final String displayName;
  final String description;
}

enum ProjectStatus {
  planning('기획 중'),
  inProgress('진행 중'),
  reviewing('검토 중'),
  submitted('제출 완료'),
  approved('승인됨'),
  rejected('반려됨'),
  completed('완료됨');

  const ProjectStatus(this.displayName);
  final String displayName;
}

class Team {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final List<TeamMember> members;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final Map<String, dynamic> settings;

  const Team({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
    this.settings = const {},
  });

  factory Team.fromMap(Map<String, dynamic> map, String id) {
    return Team(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      ownerId: map['ownerId'] ?? '',
      members: (map['members'] as List<dynamic>?)
          ?.map((member) => TeamMember.fromMap(member as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: map['updatedAt'] as Timestamp? ?? Timestamp.now(),
      settings: map['settings'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'members': members.map((member) => member.toMap()).toList(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'settings': settings,
    };
  }

  Team copyWith({
    String? name,
    String? description,
    List<TeamMember>? members,
    Map<String, dynamic>? settings,
  }) {
    return Team(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId,
      members: members ?? this.members,
      createdAt: createdAt,
      updatedAt: Timestamp.now(),
      settings: settings ?? this.settings,
    );
  }
}

class TeamMember {
  final String userId;
  final String email;
  final String displayName;
  final String? photoURL;
  final TeamRole role;
  final Timestamp joinedAt;
  final bool isActive;

  const TeamMember({
    required this.userId,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.role,
    required this.joinedAt,
    this.isActive = true,
  });

  factory TeamMember.fromMap(Map<String, dynamic> map) {
    return TeamMember(
      userId: map['userId'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoURL: map['photoURL'],
      role: TeamRole.values.firstWhere(
        (role) => role.name == map['role'],
        orElse: () => TeamRole.viewer,
      ),
      joinedAt: map['joinedAt'] as Timestamp? ?? Timestamp.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'role': role.name,
      'joinedAt': joinedAt,
      'isActive': isActive,
    };
  }
}

class CollaborationProject {
  final String id;
  final String teamId;
  final String title;
  final String description;
  final ProjectStatus status;
  final List<String> fileIds;
  final List<String> grantIds;
  final Map<String, dynamic> metadata;
  final String createdBy;
  final List<String> assignedTo;
  final Timestamp createdAt;
  final Timestamp? deadline;
  final Timestamp updatedAt;
  final List<ProjectComment> comments;

  const CollaborationProject({
    required this.id,
    required this.teamId,
    required this.title,
    required this.description,
    required this.status,
    required this.fileIds,
    required this.grantIds,
    this.metadata = const {},
    required this.createdBy,
    required this.assignedTo,
    required this.createdAt,
    this.deadline,
    required this.updatedAt,
    this.comments = const [],
  });

  factory CollaborationProject.fromMap(Map<String, dynamic> map, String id) {
    return CollaborationProject(
      id: id,
      teamId: map['teamId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      status: ProjectStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => ProjectStatus.planning,
      ),
      fileIds: List<String>.from(map['fileIds'] ?? []),
      grantIds: List<String>.from(map['grantIds'] ?? []),
      metadata: map['metadata'] as Map<String, dynamic>? ?? {},
      createdBy: map['createdBy'] ?? '',
      assignedTo: List<String>.from(map['assignedTo'] ?? []),
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      deadline: map['deadline'] as Timestamp?,
      updatedAt: map['updatedAt'] as Timestamp? ?? Timestamp.now(),
      comments: (map['comments'] as List<dynamic>?)
          ?.map((comment) => ProjectComment.fromMap(comment as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'title': title,
      'description': description,
      'status': status.name,
      'fileIds': fileIds,
      'grantIds': grantIds,
      'metadata': metadata,
      'createdBy': createdBy,
      'assignedTo': assignedTo,
      'createdAt': createdAt,
      'deadline': deadline,
      'updatedAt': updatedAt,
      'comments': comments.map((comment) => comment.toMap()).toList(),
    };
  }

  CollaborationProject copyWith({
    String? title,
    String? description,
    ProjectStatus? status,
    List<String>? fileIds,
    List<String>? grantIds,
    Map<String, dynamic>? metadata,
    List<String>? assignedTo,
    Timestamp? deadline,
    List<ProjectComment>? comments,
  }) {
    return CollaborationProject(
      id: id,
      teamId: teamId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      fileIds: fileIds ?? this.fileIds,
      grantIds: grantIds ?? this.grantIds,
      metadata: metadata ?? this.metadata,
      createdBy: createdBy,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt,
      deadline: deadline ?? this.deadline,
      updatedAt: Timestamp.now(),
      comments: comments ?? this.comments,
    );
  }
}

class ProjectComment {
  final String id;
  final String projectId;
  final String userId;
  final String userEmail;
  final String userDisplayName;
  final String content;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final String? parentId; // For threaded comments
  final List<String> attachments;

  const ProjectComment({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.userEmail,
    required this.userDisplayName,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.parentId,
    this.attachments = const [],
  });

  factory ProjectComment.fromMap(Map<String, dynamic> map) {
    return ProjectComment(
      id: map['id'] ?? '',
      projectId: map['projectId'] ?? '',
      userId: map['userId'] ?? '',
      userEmail: map['userEmail'] ?? '',
      userDisplayName: map['userDisplayName'] ?? '',
      content: map['content'] ?? '',
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: map['updatedAt'] as Timestamp?,
      parentId: map['parentId'],
      attachments: List<String>.from(map['attachments'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'userId': userId,
      'userEmail': userEmail,
      'userDisplayName': userDisplayName,
      'content': content,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'parentId': parentId,
      'attachments': attachments,
    };
  }
}

class TeamActivity {
  final String id;
  final String teamId;
  final String userId;
  final String userName;
  final TeamActivityType type;
  final String description;
  final Map<String, dynamic> metadata;
  final Timestamp createdAt;

  const TeamActivity({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.userName,
    required this.type,
    required this.description,
    this.metadata = const {},
    required this.createdAt,
  });

  factory TeamActivity.fromMap(Map<String, dynamic> map, String id) {
    return TeamActivity(
      id: id,
      teamId: map['teamId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      type: TeamActivityType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => TeamActivityType.other,
      ),
      description: map['description'] ?? '',
      metadata: map['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'userId': userId,
      'userName': userName,
      'type': type.name,
      'description': description,
      'metadata': metadata,
      'createdAt': createdAt,
    };
  }
}

enum TeamActivityType {
  teamCreated('팀 생성'),
  memberJoined('팀원 참여'),
  memberLeft('팀원 탈퇴'),
  projectCreated('프로젝트 생성'),
  projectUpdated('프로젝트 수정'),
  fileUploaded('파일 업로드'),
  fileAnalyzed('파일 분석'),
  grantMatched('지원사업 매칭'),
  commentAdded('댓글 추가'),
  statusChanged('상태 변경'),
  deadlineSet('마감일 설정'),
  other('기타');

  const TeamActivityType(this.displayName);
  final String displayName;
}