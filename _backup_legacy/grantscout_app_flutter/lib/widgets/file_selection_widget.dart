import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class FileSelectionWidget extends StatefulWidget {
  const FileSelectionWidget({super.key});

  @override
  State<FileSelectionWidget> createState() => _FileSelectionWidgetState();
}

class _FileSelectionWidgetState extends State<FileSelectionWidget> {
  final List<PlatformFile> _selectedFiles = [];
  bool _isUploading = false;
  String? _uploadError;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _selectFiles,
          icon: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                )
              : const Icon(Icons.file_upload),
          label: const Text('지원사업 공고 파일 선택'),
        ),
        const SizedBox(height: 10),
        if (_selectedFiles.isNotEmpty) _buildFileList(),
        if (_selectedFiles.isEmpty) _buildEmptyState(),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: _selectedFiles.isEmpty || _isUploading ? null : _uploadFiles,
          icon: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.cloud_upload),
          label: const Text('선택된 파일 업로드'),
        ),
        if (_uploadError != null) _buildErrorMessage(),
      ],
    );
  }

  Widget _buildFileList() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8.0),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListView.builder(
          itemCount: _selectedFiles.length,
          itemBuilder: (context, index) {
            final file = _selectedFiles[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(file.name, overflow: TextOverflow.ellipsis),
              subtitle: Text('크기: ${(file.size / 1024).toStringAsFixed(1)} KB'),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: Text('업로드할 파일을 선택해주세요.'),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        _uploadError!,
        style: const TextStyle(color: Colors.red),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _selectFiles() async {
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'hwp', 'zip'],
      );

      if (result != null) {
        _handleSelectedFiles(result.files);
      } else {
        debugPrint('파일 선택이 취소되었습니다.');
      }
    } catch (e) {
      debugPrint('파일 선택 중 오류: $e');
      if (mounted) {
        setState(() {
          _uploadError = '파일 선택 중 오류가 발생했습니다. 다시 시도해주세요.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _handleSelectedFiles(List<PlatformFile> newFiles) {
    List<PlatformFile> newFilesToAdd = [];
    List<String> existingFileNames = _selectedFiles.map((f) => f.name).toList();

    for (var newFile in newFiles) {
      if (existingFileNames.contains(newFile.name)) {
        debugPrint('중복 파일 발견: ${newFile.name}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('이미 목록에 있는 파일입니다: ${newFile.name}')),
          );
        }
      } else {
        newFilesToAdd.add(newFile);
        existingFileNames.add(newFile.name);
      }
    }

    if (newFilesToAdd.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(newFilesToAdd);
      });
      for (var file in newFilesToAdd) {
        debugPrint('새로 추가된 파일: ${file.name}, 크기: ${file.size}');
      }
    }
  }

  Future<void> _uploadFiles() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedFiles.isEmpty) {
      debugPrint('로그인되지 않았거나 선택된 파일이 없습니다.');
      if (mounted) {
        setState(() {
          _uploadError = '로그인되지 않았거나 선택된 파일이 없습니다.';
        });
      }
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      await _processFileUploads(user.uid);
    } catch (e) {
      debugPrint('파일 업로드 처리 중 오류: $e');
      if (mounted) {
        setState(() {
          _uploadError = '파일 업로드 중 오류 발생: $e';
        });
      }
    } finally {
      if (mounted && _isUploading) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _processFileUploads(String userId) async {
    final storageRef = FirebaseStorage.instance.ref();
    final batch = FirebaseFirestore.instance.batch();
    int successCount = 0;

    for (var file in _selectedFiles) {
      try {
        final filePath = _generateUniqueFilePath(userId, file.name);
        final fileRef = storageRef.child(filePath);
        
        await _uploadSingleFile(fileRef, file);
        
        final downloadUrl = await fileRef.getDownloadURL();
        _addToFirestoreBatch(batch, userId, file, filePath, downloadUrl);
        
        successCount++;
      } catch (e) {
        debugPrint('파일 업로드 오류 (${file.name}): $e');
        if (mounted) {
          setState(() {
            _uploadError = '파일 업로드 중 오류 발생 (${file.name}). 일부 파일만 업로드되었을 수 있습니다.';
          });
        }
      }
    }

    await _commitBatchWrite(batch, successCount);
  }

  String _generateUniqueFilePath(String userId, String fileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    String nameWithoutExtension = p.basenameWithoutExtension(fileName);
    String extension = p.extension(fileName).toLowerCase();
    return 'uploads/$userId/${nameWithoutExtension}_$timestamp$extension';
  }

  Future<void> _uploadSingleFile(Reference fileRef, PlatformFile file) async {
    String contentType = _getContentType(p.extension(file.name).toLowerCase());
    
    if (kIsWeb) {
      if (file.bytes != null) {
        final metadata = SettableMetadata(contentType: contentType);
        UploadTask uploadTask = fileRef.putData(file.bytes!, metadata);
        await uploadTask;
      } else {
        throw Exception('웹 환경에서 파일 바이트를 읽을 수 없습니다.');
      }
    } else {
      throw UnimplementedError('모바일 파일 업로드는 현재 구현되지 않았습니다.');
    }
  }

  String _getContentType(String extension) {
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

  void _addToFirestoreBatch(WriteBatch batch, String userId, PlatformFile file, String filePath, String downloadUrl) {
    final docRef = FirebaseFirestore.instance.collection('uploaded_files').doc();
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

  Future<void> _commitBatchWrite(WriteBatch batch, int successCount) async {
    try {
      await batch.commit();
      debugPrint('Firestore Batch Write 완료. 총 $successCount 건 성공.');
      
      if (mounted) {
        setState(() {
          _isUploading = false;
          _selectedFiles.clear();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$successCount개의 파일 업로드 및 정보 저장이 완료되었습니다.')),
        );
      }
    } catch (e) {
      debugPrint('Firestore Batch Write 오류: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadError = '파일 정보 저장 중 오류 발생: $e';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 정보 저장 중 오류 발생: $e')),
        );
      }
    }
  }
}