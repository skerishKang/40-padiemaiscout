import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:js/js.dart' as js;
import 'package:path/path.dart' as p;

@js.JS('triggerDownload')
external void triggerDownload(String url, String filename);

class FileUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<bool> uploadFiles(
    List<PlatformFile> files,
    String userId, {
    Function(double)? onProgress,
  }) async {
    final batch = _firestore.batch();
    int successCount = 0;
    int totalFiles = files.length;

    for (int i = 0; i < files.length; i++) {
      try {
        final file = files[i];
        final filePath = _generateUniqueFilePath(userId, file.name);
        final fileRef = _storage.ref().child(filePath);
        
        await _uploadSingleFile(fileRef, file);
        final downloadUrl = await fileRef.getDownloadURL();
        
        _addToFirestoreBatch(batch, userId, file, filePath, downloadUrl);
        successCount++;
        
        onProgress?.call((i + 1) / totalFiles);
      } catch (e) {
        debugPrint('파일 업로드 오류 (${files[i].name}): $e');
      }
    }

    try {
      await batch.commit();
      return successCount == totalFiles;
    } catch (e) {
      debugPrint('Firestore 배치 커밋 오류: $e');
      return false;
    }
  }

  static String _generateUniqueFilePath(String userId, String fileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final nameWithoutExtension = p.basenameWithoutExtension(fileName);
    final extension = p.extension(fileName).toLowerCase();
    return 'uploads/$userId/${nameWithoutExtension}_$timestamp$extension';
  }

  static Future<void> _uploadSingleFile(Reference fileRef, PlatformFile file) async {
    final contentType = _getContentType(p.extension(file.name).toLowerCase());
    
    if (kIsWeb) {
      if (file.bytes != null) {
        final metadata = SettableMetadata(contentType: contentType);
        await fileRef.putData(file.bytes!, metadata);
      } else {
        throw Exception('웹 환경에서 파일 바이트를 읽을 수 없습니다.');
      }
    } else {
      throw UnimplementedError('모바일 파일 업로드는 현재 구현되지 않았습니다.');
    }
  }

  static String _getContentType(String extension) {
    switch (extension) {
      case '.pdf':
        return 'application/pdf';
      case '.hwp':
        return 'application/x-hwp';
      case '.zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  static void _addToFirestoreBatch(
    WriteBatch batch,
    String userId,
    PlatformFile file,
    String filePath,
    String downloadUrl,
  ) {
    final docRef = _firestore.collection('uploaded_files').doc();
    batch.set(docRef, {
      'userId': userId,
      'fileName': file.name,
      'storagePath': filePath,
      'downloadUrl': downloadUrl,
      'fileSize': file.size,
      'uploadedAt': FieldValue.serverTimestamp(),
      'analysisStatus': 'uploaded',
    });
  }

  static Future<void> deleteFile(String documentId, String? storagePath) async {
    // Firestore 문서 삭제
    await _firestore.collection('uploaded_files').doc(documentId).delete();

    // Storage 파일 삭제
    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await _storage.ref(storagePath).delete();
      } catch (e) {
        debugPrint('Storage 파일 삭제 오류 (무시됨): $e');
      }
    }
  }

  static Future<void> downloadFile(String storagePath, String fileName) async {
    if (storagePath.isEmpty || fileName.isEmpty) {
      throw Exception('올바르지 않은 다운로드 정보입니다.');
    }

    final ref = _storage.ref(storagePath);
    final downloadUrl = await ref.getDownloadURL();

    if (kIsWeb) {
      triggerDownload(downloadUrl, fileName);
    } else {
      throw UnimplementedError('Non-web download not implemented yet.');
    }
  }
}