import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../widgets/profile_form_widget.dart';

class ProfileScreenRefactored extends StatefulWidget {
  const ProfileScreenRefactored({super.key});

  @override
  State<ProfileScreenRefactored> createState() => _ProfileScreenRefactoredState();
}

class _ProfileScreenRefactoredState extends State<ProfileScreenRefactored> {
  bool _isLoading = true;
  bool _isSaving = false;
  UserProfile? _currentProfile;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    
    if (_currentUser == null) {
      _showErrorAndGoBack('프로필을 보려면 로그인이 필요합니다.');
      return;
    }

    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() => _isLoading = true);
      
      final profile = await ProfileService.getCurrentUserProfile();
      
      if (mounted) {
        setState(() {
          _currentProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('프로필 로딩 중 오류 발생: $e');
      }
    }
  }

  Future<void> _saveProfile(UserProfile profile) async {
    try {
      setState(() => _isSaving = true);
      
      await ProfileService.saveUserProfile(profile);
      
      if (mounted) {
        setState(() {
          _currentProfile = profile;
          _isSaving = false;
        });
        
        _showSuccess('프로필이 성공적으로 저장되었습니다.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('프로필 저장 중 오류 발생: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorAndGoBack(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showError(message);
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회사 프로필 관리'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_currentProfile != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showProfileInfo,
              tooltip: '프로필 정보',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('프로필 정보를 불러오는 중...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWelcomeSection(),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ProfileFormWidget(
                initialProfile: _currentProfile,
                onSave: _saveProfile,
                isLoading: _isSaving,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Icon(
                    Icons.business,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser?.displayName ?? '사용자',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        _currentUser?.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _currentProfile == null
                  ? '회사 정보를 입력하여 맞춤형 지원사업 분석을 받아보세요.'
                  : '회사 정보를 수정하거나 업데이트할 수 있습니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileInfo() {
    if (_currentProfile == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프로필 정보'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('회사명', _currentProfile!.companyName),
              _buildInfoRow('업종', _currentProfile!.businessType),
              _buildInfoRow('설립일', _currentProfile!.establishmentDate),
              _buildInfoRow('직원 수', '${_currentProfile!.employeeCount}명'),
              _buildInfoRow('소재지', _currentProfile!.locationRegion),
              _buildInfoRow('키워드', _currentProfile!.techKeywords.join(', ')),
              if (_currentProfile!.lastUpdated != null)
                _buildInfoRow(
                  '마지막 수정',
                  _currentProfile!.lastUpdated!.toString().substring(0, 16),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}