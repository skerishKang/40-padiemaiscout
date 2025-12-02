import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:js/js.dart' as js;
import 'analysis_result_widget.dart';
import '../utils/file_utils.dart';

@js.JS('triggerDownload')
external void triggerDownload(String url, String filename);

class UploadedFilesWidget extends StatelessWidget {
  const UploadedFilesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUploadedFilesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('파일 목록 로딩 오류: ${snapshot.error}'),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('업로드된 파일이 없습니다.'));
        }

        final files = snapshot.data!.docs;
        return ListView.builder(
          itemCount: files.length,
          itemBuilder: (context, index) => _FileListItem(
            document: files[index],
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot>? _getUploadedFilesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return FirebaseFirestore.instance
        .collection('uploaded_files')
        .where('userId', isEqualTo: user.uid)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }
}

class _FileListItem extends StatelessWidget {
  final QueryDocumentSnapshot document;

  const _FileListItem({required this.document});

  @override
  Widget build(BuildContext context) {
    final data = document.data() as Map<String, dynamic>?;
    if (data == null) return const SizedBox.shrink();

    final fileName = data['fileName'] as String? ?? '이름 없음';
    final uploadedTimestamp = data['uploadedAt'] as Timestamp?;
    final uploadedAtString = uploadedTimestamp != null
        ? '${uploadedTimestamp.toDate().toLocal().toString().substring(0, 16)}'
        : '날짜 정보 없음';
    final status = data['analysisStatus'] as String? ?? '상태 미정';
    final storagePath = data['storagePath'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(
              fileName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text('업로드: $uploadedAtString | 상태: $status'),
            trailing: _buildActionButtons(context, storagePath, fileName),
            onTap: (storagePath != null && storagePath.isNotEmpty)
                ? () => _downloadFile(context, storagePath, fileName)
                : null,
          ),
          AnalysisResultWidget(
            analysisResult: data['analysisResult'],
            analysisStatus: data['analysisStatus'],
            extractedText: data['extractedTextRaw'] ?? data['extractedText'],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String? storagePath, String fileName) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.download, color: Colors.blue),
          tooltip: '다운로드',
          onPressed: (storagePath != null && storagePath.isNotEmpty)
              ? () => _downloadFile(context, storagePath, fileName)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          tooltip: '삭제',
          onPressed: () => _showDeleteConfirmation(context, fileName, storagePath),
        ),
      ],
    );
  }

  Future<void> _downloadFile(BuildContext context, String storagePath, String fileName) async {
    if (storagePath.isEmpty || fileName.isEmpty) {
      debugPrint('다운로드 오류: 유효하지 않은 storagePath 또는 fileName');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('다운로드 정보가 올바르지 않습니다.')),
        );
      }
      return;
    }

    try {
      debugPrint('파일 다운로드 시도: storagePath=$storagePath, fileName=$fileName');
      final ref = FirebaseStorage.instance.ref(storagePath);
      final downloadUrl = await ref.getDownloadURL();
      debugPrint('최신 다운로드 URL 획득: $downloadUrl');

      if (kIsWeb) {
        triggerDownload(downloadUrl, fileName);
        debugPrint('JavaScript download triggered for web via package:js.');
      } else {
        throw UnimplementedError('Non-web download not implemented yet.');
      }
    } catch (e) {
      debugPrint('파일 다운로드 오류: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('다운로드 중 오류 발생: $e')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context, String fileName, String? storagePath) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('파일 삭제 확인'),
          content: SingleChildScrollView(
            child: Text(
              '\'$fileName\' 파일을 정말 삭제하시겠습니까?\n\nFirestore 데이터와 Storage 파일이 모두 삭제되며, 삭제된 데이터는 복구할 수 없습니다.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('예, 삭제합니다'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\'$fileName\' 삭제 중...')),
      );
      
      try {
        await _deleteFile(document.id, storagePath);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('파일이 삭제되었습니다.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: ${e.toString()}')),
          );
        }
        debugPrint("Delete error: $e");
      }
    }
  }

  Future<void> _deleteFile(String documentId, String? storagePath) async {
    debugPrint('파일 삭제 시도: documentId=$documentId, storagePath=$storagePath');
    
    // Firestore 문서 삭제
    await FirebaseFirestore.instance
        .collection('uploaded_files')
        .doc(documentId)
        .delete();
    debugPrint('Firestore 문서 삭제 완료: $documentId');

    // Storage 파일 삭제
    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref(storagePath).delete();
        debugPrint('Storage 파일 삭제 완료: $storagePath');
      } catch (e) {
        debugPrint('Storage 파일 삭제 오류 (무시됨): $e');
      }
    } else {
      debugPrint('Storage 경로 정보 없음, Storage 파일 삭제 건너뜀.');
    }
  }
}