import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

abstract class AppLocalizations {
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const List<Locale> supportedLocales = [
    Locale('ko', 'KR'), // Korean
    Locale('en', 'US'), // English
  ];

  // 앱 기본
  String get appTitle;
  String get appSubtitle;
  
  // 인증
  String get signIn;
  String get signOut;
  String get signInWithGoogle;
  String get signInRequired;
  String get signInError;
  String get authenticating;
  
  // 프로필
  String get profile;
  String get profileManagement;
  String get companyProfile;
  String get companyName;
  String get businessType;
  String get establishmentDate;
  String get employeeCount;
  String get locationRegion;
  String get techKeywords;
  String get saveProfile;
  String get profileSaved;
  String get profileLoadError;
  String get profileSaveError;
  
  // 파일 관리
  String get selectFiles;
  String get uploadFiles;
  String get uploadedFiles;
  String get uploading;
  String get uploadComplete;
  String get uploadError;
  String get deleteFile;
  String get deleteConfirm;
  String get downloadFile;
  String get downloadError;
  String get noFilesSelected;
  String get noUploadedFiles;
  
  // 분석
  String get analysis;
  String get analyzing;
  String get analysisComplete;
  String get analysisError;
  String get analysisResult;
  String get suitabilityAnalysis;
  String get suitabilityScore;
  String get suitabilityReason;
  String get runAnalysis;
  String get rawGeminiResponse;
  
  // 상태
  String get status;
  String get uploaded;
  String get processing;
  String get completed;
  String get failed;
  String get unknown;
  
  // 네트워크
  String get online;
  String get offline;
  String get networkError;
  String get retryConnection;
  String get offlineMode;
  String get pendingActions;
  String get syncInProgress;
  
  // 일반적인 액션
  String get save;
  String get cancel;
  String get delete;
  String get download;
  String get upload;
  String get retry;
  String get refresh;
  String get close;
  String get ok;
  String get yes;
  String get no;
  String get back;
  String get next;
  String get previous;
  String get search;
  String get filter;
  String get settings;
  String get help;
  
  // 에러 메시지
  String get error;
  String get errorOccurred;
  String get unknownError;
  String get validationError;
  String get requiredField;
  String get invalidFormat;
  String get emailInvalid;
  String get passwordWeak;
  
  // 성공 메시지
  String get success;
  String get operationSuccessful;
  String get dataSaved;
  String get dataDeleted;
  
  // 날짜 및 시간
  String get deadline;
  String get daysRemaining;
  String get today;
  String get yesterday;
  String get tomorrow;
  String get expired;
  String get noDeadline;
  
  // 프로필 필드 힌트
  String get companyNameHint;
  String get businessTypeHint;
  String get establishmentDateHint;
  String get employeeCountHint;
  String get locationRegionHint;
  String get techKeywordsHint;
  
  // 검증 메시지
  String get companyNameRequired;
  String get businessTypeRequired;
  String get establishmentDateRequired;
  String get establishmentDateFormat;
  String get employeeCountRequired;
  String get employeeCountFormat;
  String get locationRegionRequired;
  String get techKeywordsRequired;
  
  // API 상태
  String get apiKeyStatus;
  String get apiKeyValid;
  String get apiKeyInvalid;
  String get apiKeyError;
  String get checkingApiKey;
  
  // 파일 형식
  String get supportedFileTypes;
  String get fileSize;
  String get fileSizeError;
  String get duplicateFile;
  
  // 캐시 및 저장소
  String get cache;
  String get cacheSize;
  String get clearCache;
  String get cacheClearSuccess;
  
  // 알림 및 메시지
  String get notification;
  String get information;
  String get warning;
  String get attention;
  String get noDataAvailable;
  String get loadingData;
  String get processingRequest;
  
  // 분석 관련
  String get businessName;
  String get hostOrganization;
  String get supportTarget;
  String get eligibilityCriteria;
  String get supportContent;
  String get supportAmount;
  String get applicationPeriod;
  String get applicationMethod;
  String get projectDuration;
  String get exclusionCriteria;
  String get businessKeywords;
  
  // 시간 포맷팅
  String formatDate(DateTime date);
  String formatDateTime(DateTime dateTime);
  String formatTimeAgo(DateTime dateTime);
  String formatDeadline(DateTime deadline);
  String formatFileSize(int bytes);
  
  // 복수형 처리
  String filesCount(int count);
  String daysUntilDeadline(int days);
}

// 한국어 구현
class AppLocalizationsKo extends AppLocalizations {
  @override
  String get appTitle => 'GrantScout';
  
  @override
  String get appSubtitle => '정부지원사업 분석 도우미';
  
  @override
  String get signIn => '로그인';
  
  @override
  String get signOut => '로그아웃';
  
  @override
  String get signInWithGoogle => 'Google 로그인';
  
  @override
  String get signInRequired => '로그인이 필요합니다';
  
  @override
  String get signInError => '로그인 중 오류가 발생했습니다';
  
  @override
  String get authenticating => '인증 중...';
  
  @override
  String get profile => '프로필';
  
  @override
  String get profileManagement => '프로필 관리';
  
  @override
  String get companyProfile => '회사 프로필';
  
  @override
  String get companyName => '회사명';
  
  @override
  String get businessType => '주요 업종/사업 분야';
  
  @override
  String get establishmentDate => '설립일';
  
  @override
  String get employeeCount => '상시 근로자 수';
  
  @override
  String get locationRegion => '주요 사업장 소재지 (시/도)';
  
  @override
  String get techKeywords => '핵심 키워드 (콤마로 구분)';
  
  @override
  String get saveProfile => '프로필 저장';
  
  @override
  String get profileSaved => '프로필이 성공적으로 저장되었습니다';
  
  @override
  String get profileLoadError => '프로필 로딩 중 오류 발생';
  
  @override
  String get profileSaveError => '프로필 저장 중 오류 발생';
  
  @override
  String get selectFiles => '파일 선택';
  
  @override
  String get uploadFiles => '파일 업로드';
  
  @override
  String get uploadedFiles => '업로드된 파일';
  
  @override
  String get uploading => '업로드 중...';
  
  @override
  String get uploadComplete => '업로드가 완료되었습니다';
  
  @override
  String get uploadError => '업로드 중 오류가 발생했습니다';
  
  @override
  String get deleteFile => '파일 삭제';
  
  @override
  String get deleteConfirm => '정말로 삭제하시겠습니까?';
  
  @override
  String get downloadFile => '파일 다운로드';
  
  @override
  String get downloadError => '다운로드 중 오류가 발생했습니다';
  
  @override
  String get noFilesSelected => '선택된 파일이 없습니다';
  
  @override
  String get noUploadedFiles => '업로드된 파일이 없습니다';
  
  @override
  String get analysis => '분석';
  
  @override
  String get analyzing => '분석 중...';
  
  @override
  String get analysisComplete => '분석이 완료되었습니다';
  
  @override
  String get analysisError => '분석 중 오류가 발생했습니다';
  
  @override
  String get analysisResult => '분석 결과';
  
  @override
  String get suitabilityAnalysis => '적합성 분석';
  
  @override
  String get suitabilityScore => '적합성 점수';
  
  @override
  String get suitabilityReason => '점수 사유';
  
  @override
  String get runAnalysis => '분석 실행';
  
  @override
  String get rawGeminiResponse => '원본 Gemini 응답';
  
  @override
  String get status => '상태';
  
  @override
  String get uploaded => '업로드 완료';
  
  @override
  String get processing => '처리 중';
  
  @override
  String get completed => '완료';
  
  @override
  String get failed => '실패';
  
  @override
  String get unknown => '알 수 없음';
  
  @override
  String get online => '온라인';
  
  @override
  String get offline => '오프라인';
  
  @override
  String get networkError => '네트워크 오류';
  
  @override
  String get retryConnection => '연결 재시도';
  
  @override
  String get offlineMode => '오프라인 모드';
  
  @override
  String get pendingActions => '대기 중인 작업';
  
  @override
  String get syncInProgress => '동기화 진행 중';
  
  @override
  String get save => '저장';
  
  @override
  String get cancel => '취소';
  
  @override
  String get delete => '삭제';
  
  @override
  String get download => '다운로드';
  
  @override
  String get upload => '업로드';
  
  @override
  String get retry => '재시도';
  
  @override
  String get refresh => '새로고침';
  
  @override
  String get close => '닫기';
  
  @override
  String get ok => '확인';
  
  @override
  String get yes => '예';
  
  @override
  String get no => '아니오';
  
  @override
  String get back => '뒤로';
  
  @override
  String get next => '다음';
  
  @override
  String get previous => '이전';
  
  @override
  String get search => '검색';
  
  @override
  String get filter => '필터';
  
  @override
  String get settings => '설정';
  
  @override
  String get help => '도움말';
  
  @override
  String get error => '오류';
  
  @override
  String get errorOccurred => '오류가 발생했습니다';
  
  @override
  String get unknownError => '알 수 없는 오류가 발생했습니다';
  
  @override
  String get validationError => '입력 값이 올바르지 않습니다';
  
  @override
  String get requiredField => '필수 항목입니다';
  
  @override
  String get invalidFormat => '형식이 올바르지 않습니다';
  
  @override
  String get emailInvalid => '올바른 이메일 형식이 아닙니다';
  
  @override
  String get passwordWeak => '비밀번호가 너무 약합니다';
  
  @override
  String get success => '성공';
  
  @override
  String get operationSuccessful => '작업이 성공적으로 완료되었습니다';
  
  @override
  String get dataSaved => '데이터가 저장되었습니다';
  
  @override
  String get dataDeleted => '데이터가 삭제되었습니다';
  
  @override
  String get deadline => '마감일';
  
  @override
  String get daysRemaining => '남은 일수';
  
  @override
  String get today => '오늘';
  
  @override
  String get yesterday => '어제';
  
  @override
  String get tomorrow => '내일';
  
  @override
  String get expired => '만료됨';
  
  @override
  String get noDeadline => '마감일 없음';
  
  @override
  String get companyNameHint => '예: 주식회사 커서';
  
  @override
  String get businessTypeHint => '예: 인공지능 솔루션 개발';
  
  @override
  String get establishmentDateHint => '예: 20231026';
  
  @override
  String get employeeCountHint => '숫자만 입력 (예: 15)';
  
  @override
  String get locationRegionHint => '시/도 단위 입력 (예: 서울특별시)';
  
  @override
  String get techKeywordsHint => '쉼표(,)로 구분하여 입력 (예: AI, 핀테크, 정부지원사업)';
  
  @override
  String get companyNameRequired => '회사명을 입력해주세요';
  
  @override
  String get businessTypeRequired => '업종/사업 분야를 입력해주세요';
  
  @override
  String get establishmentDateRequired => '설립일을 입력해주세요';
  
  @override
  String get establishmentDateFormat => 'YYYYMMDD 8자리로 입력해주세요';
  
  @override
  String get employeeCountRequired => '근로자 수를 입력해주세요';
  
  @override
  String get employeeCountFormat => '숫자만 입력해주세요';
  
  @override
  String get locationRegionRequired => '소재지를 입력해주세요';
  
  @override
  String get techKeywordsRequired => '키워드를 하나 이상 입력해주세요';
  
  @override
  String get apiKeyStatus => 'API 키 상태';
  
  @override
  String get apiKeyValid => 'API 키 상태: 정상';
  
  @override
  String get apiKeyInvalid => 'API 키 상태: 확인 필요';
  
  @override
  String get apiKeyError => 'API 키 상태: 확인 오류';
  
  @override
  String get checkingApiKey => 'API 키 상태 확인 중...';
  
  @override
  String get supportedFileTypes => '지원 파일 형식: PDF, HWP, ZIP';
  
  @override
  String get fileSize => '파일 크기';
  
  @override
  String get fileSizeError => '파일 크기가 너무 큽니다';
  
  @override
  String get duplicateFile => '이미 목록에 있는 파일입니다';
  
  @override
  String get cache => '캐시';
  
  @override
  String get cacheSize => '캐시 크기';
  
  @override
  String get clearCache => '캐시 삭제';
  
  @override
  String get cacheClearSuccess => '캐시가 성공적으로 삭제되었습니다';
  
  @override
  String get notification => '알림';
  
  @override
  String get information => '정보';
  
  @override
  String get warning => '경고';
  
  @override
  String get attention => '주의';
  
  @override
  String get noDataAvailable => '사용 가능한 데이터가 없습니다';
  
  @override
  String get loadingData => '데이터를 불러오는 중...';
  
  @override
  String get processingRequest => '요청을 처리하는 중...';
  
  @override
  String get businessName => '사업명';
  
  @override
  String get hostOrganization => '주관기관';
  
  @override
  String get supportTarget => '지원대상';
  
  @override
  String get eligibilityCriteria => '신청자격';
  
  @override
  String get supportContent => '지원내용';
  
  @override
  String get supportAmount => '지원규모';
  
  @override
  String get applicationPeriod => '신청기간';
  
  @override
  String get applicationMethod => '신청방법';
  
  @override
  String get projectDuration => '지원기간';
  
  @override
  String get exclusionCriteria => '신청제외대상';
  
  @override
  String get businessKeywords => '사업분야 키워드';
  
  @override
  String formatDate(DateTime date) {
    return DateFormat('yyyy년 M월 d일', 'ko_KR').format(date);
  }
  
  @override
  String formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy.MM.dd HH:mm', 'ko_KR').format(dateTime);
  }
  
  @override
  String formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }
  
  @override
  String formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now).inDays;
    
    if (difference < 0) {
      return '마감일 지남 (${-difference}일 경과)';
    } else if (difference == 0) {
      return '🚨 오늘 마감!';
    } else {
      return '마감 D-$difference';
    }
  }
  
  @override
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
  
  @override
  String filesCount(int count) {
    return '$count개 파일';
  }
  
  @override
  String daysUntilDeadline(int days) {
    if (days == 0) return '오늘 마감';
    if (days == 1) return '내일 마감';
    return '$days일 후 마감';
  }
}

// 영어 구현
class AppLocalizationsEn extends AppLocalizations {
  @override
  String get appTitle => 'GrantScout';
  
  @override
  String get appSubtitle => 'Government Grant Analysis Assistant';
  
  @override
  String get signIn => 'Sign In';
  
  @override
  String get signOut => 'Sign Out';
  
  @override
  String get signInWithGoogle => 'Sign in with Google';
  
  @override
  String get signInRequired => 'Sign in required';
  
  @override
  String get signInError => 'An error occurred during sign in';
  
  @override
  String get authenticating => 'Authenticating...';
  
  @override
  String get profile => 'Profile';
  
  @override
  String get profileManagement => 'Profile Management';
  
  @override
  String get companyProfile => 'Company Profile';
  
  @override
  String get companyName => 'Company Name';
  
  @override
  String get businessType => 'Business Type/Field';
  
  @override
  String get establishmentDate => 'Establishment Date';
  
  @override
  String get employeeCount => 'Number of Employees';
  
  @override
  String get locationRegion => 'Business Location (State/Province)';
  
  @override
  String get techKeywords => 'Key Technologies (comma separated)';
  
  @override
  String get saveProfile => 'Save Profile';
  
  @override
  String get profileSaved => 'Profile saved successfully';
  
  @override
  String get profileLoadError => 'Error loading profile';
  
  @override
  String get profileSaveError => 'Error saving profile';
  
  @override
  String get selectFiles => 'Select Files';
  
  @override
  String get uploadFiles => 'Upload Files';
  
  @override
  String get uploadedFiles => 'Uploaded Files';
  
  @override
  String get uploading => 'Uploading...';
  
  @override
  String get uploadComplete => 'Upload completed';
  
  @override
  String get uploadError => 'Error occurred during upload';
  
  @override
  String get deleteFile => 'Delete File';
  
  @override
  String get deleteConfirm => 'Are you sure you want to delete?';
  
  @override
  String get downloadFile => 'Download File';
  
  @override
  String get downloadError => 'Error occurred during download';
  
  @override
  String get noFilesSelected => 'No files selected';
  
  @override
  String get noUploadedFiles => 'No uploaded files';
  
  @override
  String get analysis => 'Analysis';
  
  @override
  String get analyzing => 'Analyzing...';
  
  @override
  String get analysisComplete => 'Analysis completed';
  
  @override
  String get analysisError => 'Error occurred during analysis';
  
  @override
  String get analysisResult => 'Analysis Result';
  
  @override
  String get suitabilityAnalysis => 'Suitability Analysis';
  
  @override
  String get suitabilityScore => 'Suitability Score';
  
  @override
  String get suitabilityReason => 'Score Reason';
  
  @override
  String get runAnalysis => 'Run Analysis';
  
  @override
  String get rawGeminiResponse => 'Raw Gemini Response';
  
  @override
  String get status => 'Status';
  
  @override
  String get uploaded => 'Uploaded';
  
  @override
  String get processing => 'Processing';
  
  @override
  String get completed => 'Completed';
  
  @override
  String get failed => 'Failed';
  
  @override
  String get unknown => 'Unknown';
  
  @override
  String get online => 'Online';
  
  @override
  String get offline => 'Offline';
  
  @override
  String get networkError => 'Network Error';
  
  @override
  String get retryConnection => 'Retry Connection';
  
  @override
  String get offlineMode => 'Offline Mode';
  
  @override
  String get pendingActions => 'Pending Actions';
  
  @override
  String get syncInProgress => 'Sync in Progress';
  
  @override
  String get save => 'Save';
  
  @override
  String get cancel => 'Cancel';
  
  @override
  String get delete => 'Delete';
  
  @override
  String get download => 'Download';
  
  @override
  String get upload => 'Upload';
  
  @override
  String get retry => 'Retry';
  
  @override
  String get refresh => 'Refresh';
  
  @override
  String get close => 'Close';
  
  @override
  String get ok => 'OK';
  
  @override
  String get yes => 'Yes';
  
  @override
  String get no => 'No';
  
  @override
  String get back => 'Back';
  
  @override
  String get next => 'Next';
  
  @override
  String get previous => 'Previous';
  
  @override
  String get search => 'Search';
  
  @override
  String get filter => 'Filter';
  
  @override
  String get settings => 'Settings';
  
  @override
  String get help => 'Help';
  
  @override
  String get error => 'Error';
  
  @override
  String get errorOccurred => 'An error occurred';
  
  @override
  String get unknownError => 'An unknown error occurred';
  
  @override
  String get validationError => 'Input value is not valid';
  
  @override
  String get requiredField => 'This field is required';
  
  @override
  String get invalidFormat => 'Invalid format';
  
  @override
  String get emailInvalid => 'Invalid email format';
  
  @override
  String get passwordWeak => 'Password is too weak';
  
  @override
  String get success => 'Success';
  
  @override
  String get operationSuccessful => 'Operation completed successfully';
  
  @override
  String get dataSaved => 'Data saved';
  
  @override
  String get dataDeleted => 'Data deleted';
  
  @override
  String get deadline => 'Deadline';
  
  @override
  String get daysRemaining => 'Days Remaining';
  
  @override
  String get today => 'Today';
  
  @override
  String get yesterday => 'Yesterday';
  
  @override
  String get tomorrow => 'Tomorrow';
  
  @override
  String get expired => 'Expired';
  
  @override
  String get noDeadline => 'No Deadline';
  
  @override
  String get companyNameHint => 'e.g. Cursor Inc.';
  
  @override
  String get businessTypeHint => 'e.g. AI Solution Development';
  
  @override
  String get establishmentDateHint => 'e.g. 20231026';
  
  @override
  String get employeeCountHint => 'Numbers only (e.g. 15)';
  
  @override
  String get locationRegionHint => 'State/Province (e.g. California)';
  
  @override
  String get techKeywordsHint => 'Comma separated (e.g. AI, Fintech, Government Support)';
  
  @override
  String get companyNameRequired => 'Please enter company name';
  
  @override
  String get businessTypeRequired => 'Please enter business type/field';
  
  @override
  String get establishmentDateRequired => 'Please enter establishment date';
  
  @override
  String get establishmentDateFormat => 'Please enter in YYYYMMDD format';
  
  @override
  String get employeeCountRequired => 'Please enter number of employees';
  
  @override
  String get employeeCountFormat => 'Please enter numbers only';
  
  @override
  String get locationRegionRequired => 'Please enter location';
  
  @override
  String get techKeywordsRequired => 'Please enter at least one keyword';
  
  @override
  String get apiKeyStatus => 'API Key Status';
  
  @override
  String get apiKeyValid => 'API Key Status: Valid';
  
  @override
  String get apiKeyInvalid => 'API Key Status: Needs Verification';
  
  @override
  String get apiKeyError => 'API Key Status: Error';
  
  @override
  String get checkingApiKey => 'Checking API key status...';
  
  @override
  String get supportedFileTypes => 'Supported file types: PDF, HWP, ZIP';
  
  @override
  String get fileSize => 'File Size';
  
  @override
  String get fileSizeError => 'File size is too large';
  
  @override
  String get duplicateFile => 'File already exists in the list';
  
  @override
  String get cache => 'Cache';
  
  @override
  String get cacheSize => 'Cache Size';
  
  @override
  String get clearCache => 'Clear Cache';
  
  @override
  String get cacheClearSuccess => 'Cache cleared successfully';
  
  @override
  String get notification => 'Notification';
  
  @override
  String get information => 'Information';
  
  @override
  String get warning => 'Warning';
  
  @override
  String get attention => 'Attention';
  
  @override
  String get noDataAvailable => 'No data available';
  
  @override
  String get loadingData => 'Loading data...';
  
  @override
  String get processingRequest => 'Processing request...';
  
  @override
  String get businessName => 'Business Name';
  
  @override
  String get hostOrganization => 'Host Organization';
  
  @override
  String get supportTarget => 'Support Target';
  
  @override
  String get eligibilityCriteria => 'Eligibility Criteria';
  
  @override
  String get supportContent => 'Support Content';
  
  @override
  String get supportAmount => 'Support Amount';
  
  @override
  String get applicationPeriod => 'Application Period';
  
  @override
  String get applicationMethod => 'Application Method';
  
  @override
  String get projectDuration => 'Project Duration';
  
  @override
  String get exclusionCriteria => 'Exclusion Criteria';
  
  @override
  String get businessKeywords => 'Business Keywords';
  
  @override
  String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy', 'en_US').format(date);
  }
  
  @override
  String formatDateTime(DateTime dateTime) {
    return DateFormat('MM/dd/yyyy HH:mm', 'en_US').format(dateTime);
  }
  
  @override
  String formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
  
  @override
  String formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now).inDays;
    
    if (difference < 0) {
      return 'Deadline passed (${-difference} days ago)';
    } else if (difference == 0) {
      return '🚨 Due Today!';
    } else {
      return '$difference days left';
    }
  }
  
  @override
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
  
  @override
  String filesCount(int count) {
    return count == 1 ? '$count file' : '$count files';
  }
  
  @override
  String daysUntilDeadline(int days) {
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in $days days';
  }
}