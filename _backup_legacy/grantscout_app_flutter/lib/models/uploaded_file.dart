import 'package:cloud_firestore/cloud_firestore.dart';

enum AnalysisStatus {
  uploaded,
  processing,
  analysisSuccess,
  textExtractedFailed,
  failed,
}

class UploadedFile {
  final String id;
  final String userId;
  final String fileName;
  final String storagePath;
  final String? downloadUrl;
  final int fileSize;
  final DateTime uploadedAt;
  final AnalysisStatus analysisStatus;
  final Map<String, dynamic>? analysisResult;
  final String? extractedTextRaw;
  final Timestamp? deadlineTimestamp;
  final String? errorDetails;

  const UploadedFile({
    required this.id,
    required this.userId,
    required this.fileName,
    required this.storagePath,
    this.downloadUrl,
    required this.fileSize,
    required this.uploadedAt,
    required this.analysisStatus,
    this.analysisResult,
    this.extractedTextRaw,
    this.deadlineTimestamp,
    this.errorDetails,
  });

  factory UploadedFile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UploadedFile(
      id: doc.id,
      userId: data['userId'] ?? '',
      fileName: data['fileName'] ?? '',
      storagePath: data['storagePath'] ?? '',
      downloadUrl: data['downloadUrl'],
      fileSize: data['fileSize'] ?? 0,
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      analysisStatus: _parseAnalysisStatus(data['analysisStatus']),
      analysisResult: data['analysisResult'],
      extractedTextRaw: data['extractedTextRaw'] ?? data['extractedText'],
      deadlineTimestamp: data['deadlineTimestamp'],
      errorDetails: data['errorDetails'],
    );
  }

  static AnalysisStatus _parseAnalysisStatus(String? status) {
    switch (status) {
      case 'uploaded':
        return AnalysisStatus.uploaded;
      case 'processing':
        return AnalysisStatus.processing;
      case 'analysis_success':
        return AnalysisStatus.analysisSuccess;
      case 'text_extracted_failed':
        return AnalysisStatus.textExtractedFailed;
      default:
        return AnalysisStatus.failed;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fileName': fileName,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'fileSize': fileSize,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'analysisStatus': analysisStatus.name,
      'analysisResult': analysisResult,
      'extractedTextRaw': extractedTextRaw,
      'deadlineTimestamp': deadlineTimestamp,
      'errorDetails': errorDetails,
    };
  }

  String get formattedUploadTime {
    return uploadedAt.toLocal().toString().substring(0, 16);
  }

  String get statusDisplayText {
    switch (analysisStatus) {
      case AnalysisStatus.uploaded:
        return '업로드 완료';
      case AnalysisStatus.processing:
        return '분석 중';
      case AnalysisStatus.analysisSuccess:
        return '분석 완료';
      case AnalysisStatus.textExtractedFailed:
        return '분석 실패';
      case AnalysisStatus.failed:
        return '오류 발생';
    }
  }

  bool get isAnalysisComplete {
    return analysisStatus == AnalysisStatus.analysisSuccess;
  }

  bool get isProcessing {
    return analysisStatus == AnalysisStatus.processing || 
           analysisStatus == AnalysisStatus.uploaded;
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  UploadedFile copyWith({
    String? id,
    String? userId,
    String? fileName,
    String? storagePath,
    String? downloadUrl,
    int? fileSize,
    DateTime? uploadedAt,
    AnalysisStatus? analysisStatus,
    Map<String, dynamic>? analysisResult,
    String? extractedTextRaw,
    Timestamp? deadlineTimestamp,
    String? errorDetails,
  }) {
    return UploadedFile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fileName: fileName ?? this.fileName,
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileSize: fileSize ?? this.fileSize,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      analysisStatus: analysisStatus ?? this.analysisStatus,
      analysisResult: analysisResult ?? this.analysisResult,
      extractedTextRaw: extractedTextRaw ?? this.extractedTextRaw,
      deadlineTimestamp: deadlineTimestamp ?? this.deadlineTimestamp,
      errorDetails: errorDetails ?? this.errorDetails,
    );
  }
}