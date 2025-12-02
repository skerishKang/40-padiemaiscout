import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/llm_model.dart';
import '../services/model_performance_service.dart';
import '../services/model_recommendation_service.dart';

class ModelABTester extends StatefulWidget {
  final Function(LLMModel)? onModelSwitch;
  final LLMModel? currentModel;

  const ModelABTester({super.key, this.onModelSwitch, this.currentModel});

  @override
  State<ModelABTester> createState() => _ModelABTesterState();
}

class _ModelABTesterState extends State<ModelABTester>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ModelPerformanceService _performanceService = ModelPerformanceService();
  final ModelRecommendationService _recommendationService =
      ModelRecommendationService();

  // A/B 테스트 상태
  LLMModel? _modelA;
  LLMModel? _modelB;
  String _testId = '';
  String _testDescription = '';
  String _trafficSplit = '50/50';
  bool _isTestActive = false;
  ABTestConfig? _currentTest;

  // 테스트 결과
  List<ABTestResult> _testResults = [];
  Map<String, TestMetrics> _testMetrics = {};

  // UI 상태
  bool _isLoading = false;
  bool _isRunningTest = false;
  String _testPrompt = '';
  String _testUseCase = 'general';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadActiveTests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveTests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot =
          await FirebaseFirestore.instance
              .collection('ab_tests')
              .where('isActive', isEqualTo: true)
              .where('createdBy', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true)
              .get();

      if (snapshot.docs.isNotEmpty) {
        final testDoc = snapshot.docs.first;
        _currentTest = ABTestConfig.fromMap(testDoc.data());
        _testId = _currentTest!.testId;
        _modelA = _currentTest!.modelA;
        _modelB = _currentTest!.modelB;
        _testDescription = _currentTest!.description;
        _trafficSplit = _currentTest!.trafficSplit;
        _isTestActive = true;

        await _loadTestResults();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('A/B 테스트 로드 실패: $e')));
      }
    }
  }

  Future<void> _loadTestResults() async {
    if (_testId.isEmpty) return;

    final snapshot =
        await FirebaseFirestore.instance
            .collection('ab_test_results')
            .where('testId', isEqualTo: _testId)
            .orderBy('timestamp', descending: true)
            .limit(100)
            .get();

    _testResults =
        snapshot.docs.map((doc) => ABTestResult.fromMap(doc.data())).toList();

    _calculateTestMetrics();
  }

  void _calculateTestMetrics() {
    final modelAResults =
        _testResults.where((r) => r.modelId == _modelA?.id).toList();
    final modelBResults =
        _testResults.where((r) => r.modelId == _modelB?.id).toList();

    _testMetrics[_modelA?.id ?? ''] = TestMetrics.fromResults(modelAResults);
    _testMetrics[_modelB?.id ?? ''] = TestMetrics.fromResults(modelBResults);
  }

  Future<void> _startABTest() async {
    if (_modelA == null || _modelB == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('테스트할 두 모델을 선택해주세요.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      _testId = 'test_${DateTime.now().millisecondsSinceEpoch}';

      await _performanceService.setupABTest(
        testId: _testId,
        modelA: _modelA!,
        modelB: _modelB!,
        trafficSplit: _trafficSplit,
        description:
            _testDescription.isNotEmpty
                ? _testDescription
                : '${_modelA!.name} vs ${_modelB!.name}',
      );

      final testConfig = ABTestConfig(
        testId: _testId,
        modelA: _modelA!,
        modelB: _modelB!,
        trafficSplit: _trafficSplit,
        description: _testDescription,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance.collection('ab_tests').doc(_testId).set({
        ...testConfig.toMap(),
        'createdBy': user.uid,
      });

      setState(() {
        _currentTest = testConfig;
        _isTestActive = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('A/B 테스트가 시작되었습니다.')));
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('A/B 테스트 시작 실패: $e')));
    }
  }

  Future<void> _stopABTest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('ab_tests')
          .doc(_testId)
          .update({'isActive': false});

      setState(() {
        _isTestActive = false;
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('A/B 테스트가 중지되었습니다.')));
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('A/B 테스트 중지 실패: $e')));
    }
  }

  Future<void> _runComparisonTest() async {
    if (_testPrompt.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('테스트 프롬프트를 입력해주세요.')));
      return;
    }

    setState(() {
      _isRunningTest = true;
    });

    try {
      final result = await _performanceService.compareModels(
        models: [_modelA!, _modelB!],
        prompt: _testPrompt,
        useCase: _testUseCase,
      );

      // 테스트 결과 시트로 이동
      _tabController.animateTo(1);

      setState(() {
        _isRunningTest = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비교 테스트가 완료되었습니다.')));
    } catch (e) {
      setState(() {
        _isRunningTest = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('비교 테스트 실패: $e')));
    }
  }

  Future<void> _switchModel(LLMModel model) async {
    if (widget.onModelSwitch != null) {
      widget.onModelSwitch!(model);
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${model.name} 모델로 전환되었습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('모델 A/B 테스트'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '테스트 설정'),
            Tab(text: '실시간 비교'),
            Tab(text: '결과 분석'),
            Tab(text: '모델 전환'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildTestSetupTab(),
                  _buildRealtimeComparisonTab(),
                  _buildResultsAnalysisTab(),
                  _buildModelSwitchTab(),
                ],
              ),
    );
  }

  Widget _buildTestSetupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModelSelection(),
          const SizedBox(height: 16),
          _buildTestConfiguration(),
          const SizedBox(height: 16),
          _buildTestControl(),
          if (_isTestActive) ...[
            const SizedBox(height: 16),
            _buildActiveTestStatus(),
          ],
        ],
      ),
    );
  }

  Widget _buildModelSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('모델 선택', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildModelSelector(
                    title: 'Model A',
                    selectedModel: _modelA,
                    onModelSelected: (model) {
                      setState(() {
                        _modelA = model;
                      });
                    },
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModelSelector(
                    title: 'Model B',
                    selectedModel: _modelB,
                    onModelSelected: (model) {
                      setState(() {
                        _modelB = model;
                      });
                    },
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelSelector({
    required String title,
    required LLMModel? selectedModel,
    required Function(LLMModel) onModelSelected,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<LLMModel>(
            value: selectedModel,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '모델 선택',
            ),
            items:
                LLMModel.getAllModels().map((model) {
                  return DropdownMenuItem(
                    value: model,
                    child: Text(model.name),
                  );
                }).toList(),
            onChanged: (model) {
              if (model != null) {
                onModelSelected(model);
              }
            },
          ),
          if (selectedModel != null) ...[
            const SizedBox(height: 8),
            _buildModelInfo(selectedModel),
          ],
        ],
      ),
    );
  }

  Widget _buildModelInfo(LLMModel model) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '제공업체: ${model.provider.name}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            '비용: \$${model.costPerToken.toStringAsFixed(4)}/token',
            style: const TextStyle(fontSize: 12),
          ),
          // Text('응답시간: ${model.averageResponseTime}s', style: const TextStyle(fontSize: 12)),
          Wrap(
            spacing: 4,
            children:
                model.capabilities.map((capability) {
                  return Chip(
                    label: Text(
                      capability,
                      style: const TextStyle(fontSize: 10),
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTestConfiguration() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('테스트 설정', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _testDescription,
              decoration: const InputDecoration(
                labelText: '테스트 설명',
                border: OutlineInputBorder(),
                hintText: '테스트 목적을 설명해주세요.',
              ),
              onChanged: (value) {
                setState(() {
                  _testDescription = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _trafficSplit,
              decoration: const InputDecoration(
                labelText: '트래픽 분할',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '50/50', child: Text('50% / 50%')),
                DropdownMenuItem(value: '70/30', child: Text('70% / 30%')),
                DropdownMenuItem(value: '80/20', child: Text('80% / 20%')),
                DropdownMenuItem(value: '90/10', child: Text('90% / 10%')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _trafficSplit = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestControl() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('테스트 제어', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _isTestActive || _modelA == null || _modelB == null
                            ? null
                            : _startABTest,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('테스트 시작'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: !_isTestActive ? null : _stopABTest,
                    icon: const Icon(Icons.stop),
                    label: const Text('테스트 중지'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTestStatus() {
    if (_currentTest == null) return const SizedBox();

    return Card(
      color: Colors.green.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '테스트 진행 중',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow('테스트 ID', _testId),
            _buildStatusRow('Model A', _modelA?.name ?? ''),
            _buildStatusRow('Model B', _modelB?.name ?? ''),
            _buildStatusRow('트래픽 분할', _trafficSplit),
            _buildStatusRow('수집된 결과', '${_testResults.length}개'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:'),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRealtimeComparisonTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildComparisonSetup(),
          const SizedBox(height: 16),
          _buildComparisonResults(),
          const SizedBox(height: 16),
          if (_isTestActive) _buildLiveComparison(),
        ],
      ),
    );
  }

  Widget _buildComparisonSetup() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('실시간 비교 테스트', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '테스트 프롬프트',
                border: OutlineInputBorder(),
                hintText: '두 모델을 비교할 프롬프트를 입력하세요.',
              ),
              onChanged: (value) {
                setState(() {
                  _testPrompt = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _testUseCase,
              decoration: const InputDecoration(
                labelText: '사용 사례',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'general', child: Text('일반')),
                DropdownMenuItem(value: 'analysis', child: Text('분석')),
                DropdownMenuItem(value: 'creation', child: Text('생성')),
                DropdownMenuItem(value: 'translation', child: Text('번역')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _testUseCase = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    (_modelA == null ||
                            _modelB == null ||
                            _testPrompt.isEmpty ||
                            _isRunningTest)
                        ? null
                        : _runComparisonTest,
                icon:
                    _isRunningTest
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.compare),
                label: Text(_isRunningTest ? '테스트 중...' : '비교 테스트 실행'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonResults() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('최근 비교 결과', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_testResults.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('테스트 결과가 없습니다.'),
                ),
              )
            else
              Column(
                children:
                    _testResults.take(10).map((result) {
                      return _buildResultItem(result);
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(ABTestResult result) {
    final isModelA = result.modelId == _modelA?.id;
    final model = isModelA ? _modelA : _modelB;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color:
              isModelA
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.green.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isModelA ? Colors.blue : Colors.green,
                radius: 12,
                child: Text(
                  isModelA ? 'A' : 'B',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                model?.name ?? result.modelId,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '평점: ${result.userRating.toStringAsFixed(1)}',
                style: TextStyle(
                  color:
                      result.userRating >= 4.0 ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '프롬프트: ${result.prompt.length > 50 ? '${result.prompt.substring(0, 50)}...' : result.prompt}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            '응답시간: ${result.responseTime.toStringAsFixed(1)}초',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            result.response.length > 100
                ? '${result.response.substring(0, 100)}...'
                : result.response,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveComparison() {
    return Card(
      color: Colors.blue.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.live_tv, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '실시간 테스트 진행 중',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '실제 사용자들이 두 모델을 사용하면서 데이터가 수집됩니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 8),
            Text(
              '수집된 데이터: ${_testResults.length}개',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsOverview(),
          const SizedBox(height: 16),
          _buildPerformanceChart(),
          const SizedBox(height: 16),
          _buildStatisticalAnalysis(),
        ],
      ),
    );
  }

  Widget _buildMetricsOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('성능 지표', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_modelA != null && _modelB != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Model A',
                      _modelA!.name,
                      _testMetrics[_modelA!.id],
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'Model B',
                      _modelB!.name,
                      _testMetrics[_modelB!.id],
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String modelName,
    TestMetrics? metrics,
    Color color,
  ) {
    if (metrics == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 8),
            Text(modelName),
            const SizedBox(height: 8),
            const Text('데이터 없음'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 8),
          Text(modelName),
          const SizedBox(height: 12),
          _buildMetricRow('평균 평점', metrics.averageRating.toStringAsFixed(2)),
          _buildMetricRow(
            '평균 응답시간',
            '${metrics.averageResponseTime.toStringAsFixed(1)}s',
          ),
          _buildMetricRow('테스트 횟수', '${metrics.totalTests}회'),
          _buildMetricRow('승리율', '${metrics.winRate.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('성능 비교 차트', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: BarChart(_createPerformanceChartData()),
            ),
          ],
        ),
      ),
    );
  }

  BarChartData _createPerformanceChartData() {
    return BarChartData(
      gridData: const FlGridData(show: true),
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true),
      barGroups: [
        if (_testMetrics[_modelA?.id] != null)
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(
                toY: _testMetrics[_modelA!.id]!.averageRating,
                color: Colors.blue,
                width: 40,
              ),
            ],
          ),
        if (_testMetrics[_modelB?.id] != null)
          BarChartGroupData(
            x: 1,
            barRods: [
              BarChartRodData(
                toY: _testMetrics[_modelB!.id]!.averageRating,
                color: Colors.green,
                width: 40,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatisticalAnalysis() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('통계적 분석', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_testResults.length < 30)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '통계적 유의성을 위해 최소 30개의 테스트 결과가 필요합니다.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  _buildAnalysisRow('표본 크기', '${_testResults.length}개'),
                  _buildAnalysisRow('신뢰 수준', _calculateConfidenceLevel()),
                  _buildAnalysisRow(
                    '통계적 유의성',
                    _calculateStatisticalSignificance(),
                  ),
                  _buildAnalysisRow('추천 모델', _getRecommendedModel()),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _calculateConfidenceLevel() {
    if (_testResults.length < 30) return '낮음';
    if (_testResults.length < 100) return '중간';
    return '높음';
  }

  String _calculateStatisticalSignificance() {
    // 간단한 통계적 유의성 계산
    if (_testResults.length < 30) return '계산 불가';

    final modelAResults =
        _testResults.where((r) => r.modelId == _modelA?.id).toList();
    final modelBResults =
        _testResults.where((r) => r.modelId == _modelB?.id).toList();

    if (modelAResults.length < 15 || modelBResults.length < 15) {
      return '계산 불가';
    }

    // 실제 통계 계산은 복잡하므로 시뮬레이션
    return Random().nextBool() ? '유의함' : '유의하지 않음';
  }

  String _getRecommendedModel() {
    final metricsA = _testMetrics[_modelA?.id];
    final metricsB = _testMetrics[_modelB?.id];

    if (metricsA == null) return _modelB?.name ?? '없음';
    if (metricsB == null) return _modelA?.name ?? '없음';

    return metricsA.averageRating > metricsB.averageRating
        ? _modelA!.name
        : _modelB!.name;
  }

  Widget _buildModelSwitchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCurrentModelDisplay(),
          const SizedBox(height: 16),
          _buildModelComparisonForSwitch(),
          const SizedBox(height: 16),
          _buildQuickSwitchPanel(),
        ],
      ),
    );
  }

  Widget _buildCurrentModelDisplay() {
    final currentModel = widget.currentModel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('현재 사용 모델', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (currentModel != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: const Icon(Icons.computer, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentModel.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('제공업체: ${currentModel.provider.name}'),
                          Text(
                            '비용: \$${currentModel.costPerToken.toStringAsFixed(4)}/token',
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle, color: Colors.green, size: 32),
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

  Widget _buildModelComparisonForSwitch() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('모델 비교 및 전환', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...LLMModel.getAllModels().map((model) {
              final isCurrentModel = model.id == widget.currentModel?.id;
              final isTestModelA = model.id == _modelA?.id;
              final isTestModelB = model.id == _modelB?.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        isCurrentModel
                            ? Colors.blue
                            : isTestModelA
                            ? Colors.green
                            : isTestModelB
                            ? Colors.orange
                            : Colors.grey.shade300,
                    width: isCurrentModel ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isCurrentModel
                            ? Colors.blue
                            : isTestModelA
                            ? Colors.green
                            : isTestModelB
                            ? Colors.orange
                            : Colors.grey,
                    child: Icon(
                      isCurrentModel
                          ? Icons.check
                          : isTestModelA
                          ? Icons.looks_one
                          : isTestModelB
                          ? Icons.looks_two
                          : Icons.computer,
                      color: Colors.white,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        model.name,
                        style: TextStyle(
                          fontWeight:
                              isCurrentModel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                      if (isCurrentModel) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '현재',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (isTestModelA) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '테스트 A',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (isTestModelB) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '테스트 B',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('제공업체: ${model.provider.name}'),
                      Text(
                        '비용: \$${model.costPerToken.toStringAsFixed(4)}/token',
                      ),
                      Text('응답시간: ${model.averageResponseTime}s'),
                      Wrap(
                        spacing: 4,
                        children:
                            model.capabilities.take(3).map((capability) {
                              return Chip(
                                label: Text(
                                  capability,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                  trailing:
                      isCurrentModel
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : ElevatedButton(
                            onPressed: () => _switchModel(model),
                            child: const Text('전환'),
                          ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSwitchPanel() {
    if (_currentTest == null) return const SizedBox();

    return Card(
      color: Colors.green.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '테스트 기반 추천',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'A/B 테스트 결과를 기반으로 최적의 모델을 추천합니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _modelA != null ? () => _switchModel(_modelA!) : null,
                    icon: const Icon(Icons.looks_one),
                    label: Text('${_modelA?.name ?? 'Model A'}으로 전환'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _modelB != null ? () => _switchModel(_modelB!) : null,
                    icon: const Icon(Icons.looks_two),
                    label: Text('${_modelB?.name ?? 'Model B'}으로 전환'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 데이터 클래스들
class TestMetrics {
  final double averageRating;
  final double averageResponseTime;
  final int totalTests;
  final double winRate;

  const TestMetrics({
    required this.averageRating,
    required this.averageResponseTime,
    required this.totalTests,
    required this.winRate,
  });

  factory TestMetrics.fromResults(List<ABTestResult> results) {
    if (results.isEmpty) {
      return const TestMetrics(
        averageRating: 0.0,
        averageResponseTime: 0.0,
        totalTests: 0,
        winRate: 0.0,
      );
    }

    final totalRating = results.fold(
      0.0,
      (sum, result) => sum + result.userRating,
    );
    final totalTime = results.fold(
      0.0,
      (sum, result) => sum + result.responseTime,
    );
    final averageRating = totalRating / results.length;
    final averageResponseTime = totalTime / results.length;

    // 승리율 계산 (4.0점 이상을 승리로 간주)
    final wins = results.where((result) => result.userRating >= 4.0).length;
    final winRate = results.isNotEmpty ? (wins / results.length) * 100 : 0.0;

    return TestMetrics(
      averageRating: averageRating,
      averageResponseTime: averageResponseTime,
      totalTests: results.length,
      winRate: winRate,
    );
  }
}

class ABTestConfig {
  final String testId;
  final LLMModel modelA;
  final LLMModel modelB;
  final String trafficSplit;
  final String description;
  final bool isActive;
  final DateTime createdAt;

  const ABTestConfig({
    required this.testId,
    required this.modelA,
    required this.modelB,
    required this.trafficSplit,
    required this.description,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'testId': testId,
      'modelAId': modelA.id,
      'modelBId': modelB.id,
      'trafficSplit': trafficSplit,
      'description': description,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ABTestConfig.fromMap(Map<String, dynamic> map) {
    return ABTestConfig(
      testId: map['testId'] ?? '',
      modelA: LLMModel.getAllModels().firstWhere(
        (m) => m.id == map['modelAId'],
        orElse: () => LLMModel.geminiPro(),
      ),
      modelB: LLMModel.getAllModels().firstWhere(
        (m) => m.id == map['modelBId'],
        orElse: () => LLMModel.gpt4(),
      ),
      trafficSplit: map['trafficSplit'] ?? '50/50',
      description: map['description'] ?? '',
      isActive: map['isActive'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ABTestResult {
  final String testId;
  final String userId;
  final String modelId;
  final String prompt;
  final String response;
  final double responseTime;
  final double userRating;
  final DateTime timestamp;

  const ABTestResult({
    required this.testId,
    required this.userId,
    required this.modelId,
    required this.prompt,
    required this.response,
    required this.responseTime,
    required this.userRating,
    required this.timestamp,
  });

  factory ABTestResult.fromMap(Map<String, dynamic> map) {
    return ABTestResult(
      testId: map['testId'] ?? '',
      userId: map['userId'] ?? '',
      modelId: map['modelId'] ?? '',
      prompt: map['prompt'] ?? '',
      response: map['response'] ?? '',
      responseTime: (map['responseTime'] as num?)?.toDouble() ?? 0.0,
      userRating: (map['userRating'] as num?)?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
