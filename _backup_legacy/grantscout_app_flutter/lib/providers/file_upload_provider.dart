import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/uploaded_file.dart';
import '../services/file_upload_service.dart';

enum FileUploadState {
  idle,
  selecting,
  uploading,
  error,
}

class FileUploadProvider extends ChangeNotifier {
  FileUploadState _state = FileUploadState.idle;
  List<PlatformFile> _selectedFiles = [];
  List<UploadedFile> _uploadedFiles = [];
  String? _errorMessage;
  double _uploadProgress = 0.0;

  FileUploadState get state => _state;
  List<PlatformFile> get selectedFiles => List.unmodifiable(_selectedFiles);
  List<UploadedFile> get uploadedFiles => List.unmodifiable(_uploadedFiles);
  String? get errorMessage => _errorMessage;
  double get uploadProgress => _uploadProgress;
  bool get hasSelectedFiles => _selectedFiles.isNotEmpty;
  bool get isUploading => _state == FileUploadState.uploading;

  Stream<QuerySnapshot>? _uploadedFilesStream;

  void startListeningToUploadedFiles(String userId) {
    _uploadedFilesStream = FirebaseFirestore.instance
        .collection('uploaded_files')
        .where('userId', isEqualTo: userId)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
        
    _uploadedFilesStream!.listen((snapshot) {
      _uploadedFiles = snapshot.docs
          .map((doc) => UploadedFile.fromFirestore(doc))
          .toList();
      notifyListeners();
    });
  }

  void stopListeningToUploadedFiles() {
    _uploadedFilesStream = null;
  }

  Future<void> selectFiles() async {
    try {
      _setState(FileUploadState.selecting);
      
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'hwp', 'zip'],
      );

      if (result != null) {
        _addSelectedFiles(result.files);
      }
      
      _setState(FileUploadState.idle);
    } catch (e) {
      _setError('파일 선택 중 오류가 발생했습니다: $e');
    }
  }

  void _addSelectedFiles(List<PlatformFile> newFiles) {
    final existingNames = _selectedFiles.map((f) => f.name).toSet();
    final filesToAdd = newFiles.where((file) => !existingNames.contains(file.name)).toList();
    
    _selectedFiles.addAll(filesToAdd);
    notifyListeners();
  }

  void removeSelectedFile(int index) {
    if (index >= 0 && index < _selectedFiles.length) {
      _selectedFiles.removeAt(index);
      notifyListeners();
    }
  }

  void clearSelectedFiles() {
    _selectedFiles.clear();
    notifyListeners();
  }

  Future<bool> uploadFiles(String userId) async {
    if (_selectedFiles.isEmpty) return false;

    try {
      _setState(FileUploadState.uploading);
      _uploadProgress = 0.0;

      final success = await FileUploadService.uploadFiles(
        _selectedFiles,
        userId,
        onProgress: (progress) {
          _uploadProgress = progress;
          notifyListeners();
        },
      );

      if (success) {
        _selectedFiles.clear();
        _setState(FileUploadState.idle);
        return true;
      } else {
        _setError('일부 파일 업로드에 실패했습니다.');
        return false;
      }
    } catch (e) {
      _setError('파일 업로드 중 오류가 발생했습니다: $e');
      return false;
    }
  }

  Future<bool> deleteFile(String documentId, String? storagePath) async {
    try {
      await FileUploadService.deleteFile(documentId, storagePath);
      return true;
    } catch (e) {
      _setError('파일 삭제 중 오류가 발생했습니다: $e');
      return false;
    }
  }

  Future<bool> downloadFile(String storagePath, String fileName) async {
    try {
      await FileUploadService.downloadFile(storagePath, fileName);
      return true;
    } catch (e) {
      _setError('파일 다운로드 중 오류가 발생했습니다: $e');
      return false;
    }
  }

  void _setState(FileUploadState newState) {
    _state = newState;
    if (newState != FileUploadState.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _state = FileUploadState.error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_state == FileUploadState.error) {
      _state = FileUploadState.idle;
    }
    notifyListeners();
  }
}