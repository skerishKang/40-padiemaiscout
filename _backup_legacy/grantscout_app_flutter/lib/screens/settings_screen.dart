import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/llm_model.dart';
import '../widgets/llm_model_selector.dart';
import '../widgets/llm_model_comparison.dart';
import '../widgets/cost_efficiency_analyzer.dart';
import '../widgets/model_ab_tester.dart';
import '../services/api_key_service.dart';
import '../utils/error_handler.dart';
import '../profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  LLMConfig? _currentConfig;
  LLMModel? _currentModel;
  Map<String, dynamic> _apiStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // LLM 설정 불러오기
        final configDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('llm_config')
            .get();

        if (configDoc.exists) {
          _currentConfig = LLMConfig.fromMap(configDoc.data()!);
          // 현재 모델 설정
          _currentModel = LLMModel.getAllModels().firstWhere(
            (model) => model.id == _currentConfig!.modelId,
            orElse: () => LLMModel.geminiPro(),
          );
        } else {
          _currentModel = LLMModel.geminiPro(); // 기본 모델
        }

        // API 키 통계 불러오기
        _apiStats = await ApiKeyService.getApiKeyStats();
      }
    } catch (e) {
      final error = ErrorHandler.handleError(e);
      ErrorHandler.logError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.psychology), text: 'AI 모델'),
            Tab(icon: Icon(Icons.compare), text: '모델 비교'),
            Tab(icon: Icon(Icons.analytics), text: '비용 분석'),
            Tab(icon: Icon(Icons.science), text: 'A/B 테스트'),
            Tab(icon: Icon(Icons.vpn_key), text: 'API 키'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAIModelTab(),
                _buildModelComparisonTab(),
                _buildCostAnalysisTab(),
                _buildABTestTab(),
                _buildApiKeyTab(),
              ],
            ),
    );
  }

  Widget _buildAIModelTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCurrentModelDisplay(),
          const SizedBox(height: 20),
          LLMModelSelector(
            currentConfig: _currentConfig,
            onConfigChanged: (config) {
              setState(() {
                _currentConfig = config;
                // 현재 모델 업데이트
                _currentModel = LLMModel.getAllModels().firstWhere(
                  (model) => model.id == config.modelId,
                  orElse: () => LLMModel.geminiPro(),
                );
              });
            },
          ),
          const SizedBox(height: 20),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildCurrentModelDisplay() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  '현재 AI 모델',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_currentModel != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      radius: 24,
                      child: Icon(
                        Icons.computer,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentModel!.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('제공업체: ${_currentModel!.provider.name}'),
                          Text('비용: \$${_currentModel!.costPerToken.toStringAsFixed(4)}/token'),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '활성',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('선택된 모델이 없습니다.'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '빠른 작업',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _tabController.animateTo(1); // 모델 비교 탭으로 이동
                    },
                    icon: const Icon(Icons.compare),
                    label: const Text('모델 비교'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _tabController.animateTo(2); // 비용 분석 탭으로 이동
                    },
                    icon: const Icon(Icons.analytics),
                    label: const Text('비용 분석'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _tabController.animateTo(3); // A/B 테스트 탭으로 이동
                },
                icon: const Icon(Icons.science),
                label: const Text('A/B 테스트 시작'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelComparisonTab() {
    return LLMModelComparison(
      currentModel: _currentModel,
      onModelSelected: (model) {
        setState(() {
          _currentModel = model;
          // 설정 업데이트
          _updateModelConfig(model);
        });
      },
    );
  }

  Widget _buildCostAnalysisTab() {
    return CostEfficiencyAnalyzer(
      onModelSelected: (model) {
        setState(() {
          _currentModel = model;
          _updateModelConfig(model);
        });
      },
    );
  }

  Widget _buildABTestTab() {
    return ModelABTester(
      currentModel: _currentModel,
      onModelSwitch: (model) {
        setState(() {
          _currentModel = model;
          _updateModelConfig(model);
        });
      },
    );
  }

  Future<void> _updateModelConfig(LLMModel model) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // LLM 설정 저장
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('llm_config')
            .set({
              'modelId': model.id,
              'provider': model.provider.name,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        // 현재 설정 업데이트
        _currentConfig = LLMConfig(
          modelId: model.id,
          provider: model.provider,
          apiKey: '', // API 키는 별도로 관리
          temperature: 0.7,
          maxTokens: model.maxTokens,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${model.name} 모델로 변경되었습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('모델 변경 실패: $e')),
        );
      }
    }
  }

  Widget _buildApiKeyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildApiKeyStats(),
          const SizedBox(height: 20),
          _buildApiKeyList(),
          const SizedBox(height: 20),
          _buildApiKeyActions(),
        ],
      ),
    );
  }

  Widget _buildApiKeyStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'API 키 통계',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('총 키', '${_apiStats['totalKeys'] ?? 0}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '마지막 사용',
                    _apiStats['lastUsedDays'] != null
                        ? '${_apiStats['lastUsedDays']}일 전'
                        : '없음',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '저장된 API 키',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, String>>(
              future: ApiKeyService.getAllApiKeys(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('저장된 API 키가 없습니다.'),
                  );
                }

                final apiKeys = snapshot.data!;
                return ListView(
                  shrinkWrap: true,
                  children: apiKeys.entries.map((entry) {
                    return ListTile(
                      title: Text(entry.key.toUpperCase()),
                      subtitle: Text('●●●●●●●●●●●●${entry.value.substring(entry.value.length - 4)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteApiKey(entry.key),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'API 키 관리',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _backupApiKeys,
                    icon: const Icon(Icons.backup),
                    label: const Text('백업'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _restoreApiKeys,
                    icon: const Icon(Icons.restore),
                    label: const Text('복원'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clearAllApiKeys,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text('모든 키 삭제', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildUserInfoSection(),
          const SizedBox(height: 20),
          _buildPreferencesSection(),
          const SizedBox(height: 20),
          _buildDangerZone(),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '사용자 정보',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: CircleAvatar(
                backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                child: user.photoURL == null ? const Icon(Icons.person) : null,
              ),
              title: Text(user.displayName ?? '사용자'),
              subtitle: Text(user.email ?? ''),
              trailing: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
                child: const Text('프로필 편집'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '환경 설정',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('알림 받기'),
              subtitle: const Text('마감일 임박 알림 등'),
              value: true, // TODO: 실제 설정 값 로드
              onChanged: (value) {
                // TODO: 설정 저장
              },
            ),
            SwitchListTile(
              title: const Text('자동 분석'),
              subtitle: const Text('파일 업로드 시 자동으로 AI 분석'),
              value: false, // TODO: 실제 설정 값 로드
              onChanged: (value) {
                // TODO: 설정 저장
              },
            ),
            ListTile(
              title: const Text('언어'),
              subtitle: const Text('한국어'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: 언어 선택 화면
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red[700]),
                const SizedBox(width: 8),
                Text(
                  '위험 영역',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _clearAllData,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text(
                  '모든 데이터 삭제',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteApiKey(String provider) async {
    final confirmed = await _showConfirmDialog(
      'API 키 삭제',
      '$provider API 키를 정말 삭제하시겠습니까?',
    );

    if (confirmed) {
      try {
        await ApiKeyService.deleteApiKey(provider);
        _loadSettings(); // 새로고침
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('API 키가 삭제되었습니다.')),
          );
        }
      } catch (e) {
        final error = ErrorHandler.handleError(e);
        ErrorHandler.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _backupApiKeys() async {
    try {
      await ApiKeyService.backupApiKeys();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API 키가 백업되었습니다.')),
        );
      }
    } catch (e) {
      final error = ErrorHandler.handleError(e);
      ErrorHandler.showErrorSnackBar(context, error);
    }
  }

  Future<void> _restoreApiKeys() async {
    final confirmed = await _showConfirmDialog(
      'API 키 복원',
      '백업된 API 키를 복원하시겠습니까?\n기존 키는 덮어쓰기 됩니다.',
    );

    if (confirmed) {
      try {
        // TODO: 실제 복원 로직 구현
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('API 키 복원 기능은 준비 중입니다.')),
          );
        }
      } catch (e) {
        final error = ErrorHandler.handleError(e);
        ErrorHandler.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _clearAllApiKeys() async {
    final confirmed = await _showConfirmDialog(
      '모든 API 키 삭제',
      '저장된 모든 API 키를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
    );

    if (confirmed) {
      try {
        await ApiKeyService.clearAllApiKeys();
        _loadSettings(); // 새로고침
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('모든 API 키가 삭제되었습니다.')),
          );
        }
      } catch (e) {
        final error = ErrorHandler.handleError(e);
        ErrorHandler.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await _showConfirmDialog(
      '모든 데이터 삭제',
      '모든 데이터를 정말 삭제하시겠습니까?\n파일, 설정, API 키 등 모든 정보가 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.',
    );

    if (confirmed) {
      // TODO: 실제 데이터 삭제 로직 구현
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('데이터 삭제 기능은 준비 중입니다.')),
        );
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}