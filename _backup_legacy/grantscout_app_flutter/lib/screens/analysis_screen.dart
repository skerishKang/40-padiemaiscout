import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/gemini_service.dart';
import '../profile_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;
  
  // File Data
  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;

  // Analysis Result
  GrantAnalysisResult? _result;

  // User Profile
  Map<String, dynamic> _userProfile = {};

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(user.uid)
          .get();
      
      if (doc.exists && doc.data() != null) {
        setState(() {
          _userProfile = doc.data()!;
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true, // Important for web and direct byte access
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
          _fileBytes = result.files.first.bytes;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "파일 선택 중 오류가 발생했습니다: $e";
      });
    }
  }

  Future<void> _analyzeFile() async {
    if (_selectedFile == null || _fileBytes == null) {
      setState(() => _errorMessage = "분석할 파일을 선택해주세요.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Determine mime type
      String mimeType = 'application/pdf';
      final ext = _selectedFile!.extension?.toLowerCase();
      if (ext == 'png') mimeType = 'image/png';
      if (ext == 'jpg' || ext == 'jpeg') mimeType = 'image/jpeg';

      final result = await GeminiService.analyzeGrantDocument(
        fileBytes: _fileBytes!,
        mimeType: mimeType,
        companyProfile: _userProfile,
      );

      setState(() {
        _result = result;
        _currentStep = 2; // Move to results
      });
    } catch (e) {
      setState(() {
        _errorMessage = "분석 실패: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 공고 분석'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
              _loadUserProfile(); // Reload after return
            },
          )
        ],
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0) {
            setState(() => _currentStep = 1);
          } else if (_currentStep == 1) {
            _analyzeFile();
          } else {
            // Finish or Reset
            setState(() {
              _currentStep = 0;
              _selectedFile = null;
              _result = null;
            });
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        controlsBuilder: (context, details) {
          if (_isLoading) return const SizedBox.shrink();
          
          return Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Row(
              children: [
                if (_currentStep != 2)
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: Text(_currentStep == 1 ? '분석 시작' : '다음'),
                  ),
                if (_currentStep != 0 && _currentStep != 2)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('이전'),
                  ),
                if (_currentStep == 2)
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: const Text('새로운 분석'),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('회사 프로필 확인'),
            content: _buildProfileStep(),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('공고문 업로드'),
            content: _buildUploadStep(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('분석 결과'),
            content: _buildResultStep(),
            isActive: _currentStep >= 2,
            state: _currentStep == 2 ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    final hasProfile = _userProfile.isNotEmpty && _userProfile['companyName'] != null;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasProfile) ...[
              Text("회사명: ${_userProfile['companyName']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("업종: ${_userProfile['businessType']}"),
              const SizedBox(height: 10),
              const Text("✅ 프로필이 등록되어 있습니다. 맞춤형 분석이 가능합니다.", style: TextStyle(color: Colors.green)),
            ] else ...[
              const Text("⚠️ 등록된 회사 프로필이 없습니다.", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              const Text("프로필 없이도 분석은 가능하지만, 적합도 점수가 정확하지 않을 수 있습니다."),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                  _loadUserProfile();
                },
                child: const Text("프로필 등록하기"),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildUploadStep() {
    return Column(
      children: [
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.red.shade100,
            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade50,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload, size: 50, color: Colors.blue.shade300),
                const SizedBox(height: 10),
                Text(_selectedFile != null ? _selectedFile!.name : "PDF 또는 이미지 파일을 선택하세요"),
              ],
            ),
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text("AI가 문서를 분석 중입니다..."),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResultStep() {
    if (_result == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildScoreCard(),
        const SizedBox(height: 20),
        _buildInfoCard("📌 공고 요약", _result!.summary),
        _buildInfoCard("💰 지원 규모", _result!.fundingAmount),
        _buildInfoCard("📅 마감일", _result!.deadline),
        _buildListCard("✅ 자격 요건", _result!.eligibilityCriteria),
        _buildListCard("📄 제출 서류", _result!.keyRequirements),
        _buildInfoCard("🤔 적합도 분석", _result!.suitabilityReasoning),
      ],
    );
  }

  Widget _buildScoreCard() {
    Color color = Colors.grey;
    if (_result!.matchStatus == 'High') color = Colors.green;
    if (_result!.matchStatus == 'Medium') color = Colors.orange;
    if (_result!.matchStatus == 'Low') color = Colors.red;

    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircularProgressIndicator(
              value: _result!.suitabilityScore / 100,
              backgroundColor: Colors.grey.shade300,
              color: color,
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_result!.suitabilityScore}점 / ${_result!.matchStatus}",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                ),
                Text(_result!.grantTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(_result!.issuingAgency),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(content),
      ),
    );
  }

  Widget _buildListCard(String title, List<String> items) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ...items.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(e)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
