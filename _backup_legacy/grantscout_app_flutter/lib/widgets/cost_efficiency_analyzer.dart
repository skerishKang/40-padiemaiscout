import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/llm_model.dart';
import '../services/model_recommendation_service.dart';
import '../services/model_performance_service.dart';

class CostEfficiencyAnalyzer extends StatefulWidget {
  final Function(LLMModel)? onModelSelected;
  final double? monthlyBudget;
  final int? expectedUsage;

  const CostEfficiencyAnalyzer({
    super.key,
    this.onModelSelected,
    this.monthlyBudget,
    this.expectedUsage = 1000,
  });

  @override
  State<CostEfficiencyAnalyzer> createState() => _CostEfficiencyAnalyzerState();
}

class _CostEfficiencyAnalyzerState extends State<CostEfficiencyAnalyzer>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ModelRecommendationService _recommendationService = ModelRecommendationService();
  final ModelPerformanceService _performanceService = ModelPerformanceService();

  UseCaseType _selectedUseCase = UseCaseType.grantAnalysis;
  double _monthlyBudget = 100.0;
  int _expectedUsage = 1000;
  bool _isLoading = false;
  CostOptimizationRecommendation? _recommendation;
  List<CostProjection> _projections = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _monthlyBudget = widget.monthlyBudget ?? 100.0;
    _expectedUsage = widget.expectedUsage ?? 1000;
    _loadRecommendations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final recommendation = await _recommendationService.getCostOptimizedRecommendation(
        useCase: _selectedUseCase,
        monthlyBudget: _monthlyBudget,
        expectedMonthlyUsage: _expectedUsage,
      );

      final projections = await _generateCostProjections();

      setState(() {
        _recommendation = recommendation;
        _projections = projections;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('비용 분석 로드 실패: $e')),
        );
      }
    }
  }

  Future<List<CostProjection>> _generateCostProjections() async {
    final models = LLMModel.getAllModels();
    final projections = <CostProjection>[];

    for (final model in models) {
      final performanceData = await _performanceService.getModelPerformance(
        modelId: model.id,
        useCase: _selectedUseCase.name,
      );

      final projection = CostProjection(
        model: model,
        monthlyCosts: _calculateMonthlyCosts(model, 6),
        performanceScores: _calculatePerformanceProjections(model, 6),
        efficiencyScores: _calculateEfficiencyScores(model, performanceData),
      );

      projections.add(projection);
    }

    return projections;
  }

  List<MonthlyCost> _calculateMonthlyCosts(LLMModel model, int months) {
    final costs = <MonthlyCost>[];
    final baseCost = _expectedUsage * model.costPerToken * 1000;

    for (int i = 0; i < months; i++) {
      // 사용량 증가 가정 (월 10% 증가)
      final usageGrowth = 1.0 + (i * 0.1);
      final monthlyCost = baseCost * usageGrowth;

      costs.add(MonthlyCost(
        month: i + 1,
        cost: monthlyCost,
        usage: (_expectedUsage * usageGrowth).round(),
      ));
    }

    return costs;
  }

  List<double> _calculatePerformanceProjections(LLMModel model, int months) {
    final performances = <double>[];
    final basePerformance = 7.0; // 기본 성능 점수

    for (int i = 0; i < months; i++) {
      // 성능 향상 가정 (모델 개선)
      final performanceImprovement = 1.0 + (i * 0.02);
      performances.add((basePerformance * performanceImprovement).clamp(0.0, 10.0));
    }

    return performances;
  }

  double _calculateEfficiencyScores(LLMModel model, ModelPerformanceData performanceData) {
    final costScore = (1.0 / model.costPerToken) * 100;
    final performanceScore = performanceData.overallScore;
    final efficiencyScore = (costScore + performanceScore) / 2;

    return efficiencyScore.clamp(0.0, 10.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('비용 효율 분석'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '비용 비교'),
            Tab(text: '효율성 분석'),
            Tab(text: '예상 비용'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildControlPanel(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCostComparisonTab(),
                _buildEfficiencyAnalysisTab(),
                _buildProjectionTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<UseCaseType>(
                  value: _selectedUseCase,
                  decoration: const InputDecoration(
                    labelText: '사용 사례',
                    border: OutlineInputBorder(),
                  ),
                  items: UseCaseType.values.map((useCase) {
                    return DropdownMenuItem(
                      value: useCase,
                      child: Text(useCase.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedUseCase = value;
                      });
                      _loadRecommendations();
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  initialValue: _monthlyBudget.toStringAsFixed(0),
                  decoration: const InputDecoration(
                    labelText: '월 예산 (\$)',
                    border: OutlineInputBorder(),
                    prefixText: '\$',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final budget = double.tryParse(value);
                    if (budget != null && budget > 0) {
                      setState(() {
                        _monthlyBudget = budget;
                      });
                      _loadRecommendations();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _expectedUsage.toString(),
                  decoration: const InputDecoration(
                    labelText: '월 사용량 (요청)',
                    border: OutlineInputBorder(),
                    suffixText: '회',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final usage = int.tryParse(value);
                    if (usage != null && usage > 0) {
                      setState(() {
                        _expectedUsage = usage;
                      });
                      _loadRecommendations();
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadRecommendations,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isLoading ? '분석 중...' : '다시 분석'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostComparisonTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recommendation == null) {
      return const Center(child: Text('분석 데이터가 없습니다.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 16),
          _buildCostComparisonChart(),
          const SizedBox(height: 16),
          _buildRecommendationList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_recommendation == null) return const SizedBox();

    final topRecommendation = _recommendation!.recommendations.first;
    final totalSavings = _recommendation!.estimatedSavings;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '분석 요약',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    '추천 모델',
                    topRecommendation.model.name,
                    Icons.recommend,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    '예상 월 비용',
                    '\$${topRecommendation.monthlyEstimate.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    '예상 절감액',
                    '\$${totalSavings.toStringAsFixed(2)}',
                    Icons.savings,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    '효율성 점수',
                    topRecommendation.costAnalysis.costEfficiencyScore.toStringAsFixed(2),
                    Icons.speed,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostComparisonChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '월별 비용 비교',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: _projections.isEmpty
                  ? const Center(child: Text('차트 데이터가 없습니다.'))
                  : LineChart(
                      _createCostComparisonData(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _createCostComparisonData() {
    final topModels = _projections.take(5).toList();

    return LineChartData(
      gridData: const FlGridData(show: true),
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true),
        ),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true),
      lineBarsData: topModels.asMap().entries.map((entry) {
        final index = entry.key;
        final projection = entry.value;
        final colors = [
          Colors.blue,
          Colors.green,
          Colors.orange,
          Colors.purple,
          Colors.red,
        ];

        return LineChartBarData(
          spots: projection.monthlyCosts.asMap().entries.map((costEntry) {
            return FlSpot(
              costEntry.key.toDouble() + 1,
              costEntry.value.cost,
            );
          }).toList(),
          isCurved: true,
          color: colors[index % colors.length],
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: colors[index % colors.length].withOpacity(0.1),
          ),
        );
      }).toList(),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildRecommendationList() {
    if (_recommendation == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '추천 목록',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._recommendation!.recommendations.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return _buildRecommendationItem(item, index == 0);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationItem(CostOptimizationItem item, bool isTopRecommendation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isTopRecommendation ? Colors.green : Colors.grey.shade300,
          width: isTopRecommendation ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isTopRecommendation ? Colors.green : Colors.grey.shade200,
          child: Icon(
            isTopRecommendation ? Icons.star : Icons.computer,
            color: isTopRecommendation ? Colors.white : Colors.grey.shade600,
          ),
        ),
        title: Row(
          children: [
            Text(
              item.model.name,
              style: TextStyle(
                fontWeight: isTopRecommendation ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isTopRecommendation) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '추천',
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
            Text('월 예상 비용: \$${item.monthlyEstimate.toStringAsFixed(2)}'),
            Text('절감 가능액: \$${item.savingsPotential.toStringAsFixed(2)}'),
            if (item.tradeoffs.isNotEmpty)
              Text('고려사항: ${item.tradeoffs.join(', ')}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.costAnalysis.costEfficiencyScore.toStringAsFixed(1),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Text('효율성', style: TextStyle(fontSize: 10)),
          ],
        ),
        onTap: () {
          if (widget.onModelSelected != null) {
            widget.onModelSelected!(item.model);
          }
        },
      ),
    );
  }

  Widget _buildEfficiencyAnalysisTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEfficiencyMatrix(),
          const SizedBox(height: 16),
          _buildPerformanceVsCostChart(),
          const SizedBox(height: 16),
          _buildDetailedAnalysis(),
        ],
      ),
    );
  }

  Widget _buildEfficiencyMatrix() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '효율성 매트릭스',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: _projections.isEmpty
                  ? const Center(child: Text('데이터가 없습니다.'))
                  : ScatterChart(
                      _createEfficiencyMatrixData(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  ScatterChartData _createEfficiencyMatrixData() {
    return ScatterChartData(
      gridData: const FlGridData(show: true),
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true),
      scatterSpots: _projections.map((projection) {
        return ScatterSpot(
          projection.monthlyCosts.first.cost,
          projection.efficiencyScores,
        );
      }).toList(),
      scatterTouchData: ScatterTouchData(
        touchTooltipData: ScatterTouchTooltipData(
          tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildPerformanceVsCostChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '성능 vs 비용',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: BarChart(
                _createPerformanceVsCostData(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartData _createPerformanceVsCostData() {
    return BarChartData(
      gridData: const FlGridData(show: true),
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true),
      barGroups: _projections.take(5).map((projection) {
        return BarChartGroupData(
          x: _projections.indexOf(projection),
          barRods: [
            BarChartRodData(
              toY: projection.monthlyCosts.first.cost,
              color: Colors.blue,
              width: 20,
            ),
            BarChartRodData(
              toY: projection.efficiencyScores * 10,
              color: Colors.green,
              width: 20,
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDetailedAnalysis() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '상세 분석',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._projections.map((projection) {
              return ExpansionTile(
                title: Text(projection.model.name),
                subtitle: Text(
                  '효율성: ${projection.efficiencyScores.toStringAsFixed(2)}',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAnalysisRow(
                          '평균 월 비용',
                          '\$${(projection.monthlyCosts.map((c) => c.cost).reduce((a, b) => a + b) / projection.monthlyCosts.length).toStringAsFixed(2)}',
                        ),
                        _buildAnalysisRow(
                          '평균 성능 점수',
                          (projection.performanceScores.reduce((a, b) => a + b) / projection.performanceScores.length).toStringAsFixed(2),
                        ),
                        _buildAnalysisRow(
                          '비용 증가율',
                          '${((projection.monthlyCosts.last.cost - projection.monthlyCosts.first.cost) / projection.monthlyCosts.first.cost * 100).toStringAsFixed(1)}%',
                        ),
                        _buildAnalysisRow(
                          '성능 향상률',
                          '${((projection.performanceScores.last - projection.performanceScores.first) / projection.performanceScores.first * 100).toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectionTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProjectionSettings(),
          const SizedBox(height: 16),
          _buildProjectionChart(),
          const SizedBox(height: 16),
          _buildProjectionTable(),
        ],
      ),
    );
  }

  Widget _buildProjectionSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '예상 설정',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: '6',
                    decoration: const InputDecoration(
                      labelText: '예상 기간 (월)',
                      border: OutlineInputBorder(),
                      suffixText: '개월',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      // 기간 업데이트 로직
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: '10',
                    decoration: const InputDecoration(
                      labelText: '월 사용량 증가율',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      // 증가율 업데이트 로직
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectionChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '비용 예상',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: _projections.isEmpty
                  ? const Center(child: Text('데이터가 없습니다.'))
                  : LineChart(
                      _createProjectionChartData(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _createProjectionChartData() {
    return LineChartData(
      gridData: const FlGridData(show: true),
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true),
      lineBarsData: _projections.take(3).map((projection) {
        return LineChartBarData(
          spots: projection.monthlyCosts.asMap().entries.map((entry) {
            return FlSpot(
              entry.key.toDouble() + 1,
              entry.value.cost,
            );
          }).toList(),
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
        );
      }).toList(),
    );
  }

  Widget _buildProjectionTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '월별 예상 비용',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('모델')),
                  DataColumn(label: Text('1개월')),
                  DataColumn(label: Text('3개월')),
                  DataColumn(label: Text('6개월')),
                  DataColumn(label: Text('총계')),
                ],
                rows: _projections.take(5).map((projection) {
                  final costs = projection.monthlyCosts;
                  final total1 = costs.take(1).fold(0.0, (sum, cost) => sum + cost.cost);
                  final total3 = costs.take(3).fold(0.0, (sum, cost) => sum + cost.cost);
                  final total6 = costs.fold(0.0, (sum, cost) => sum + cost.cost);

                  return DataRow(
                    cells: [
                      DataCell(Text(projection.model.name)),
                      DataCell(Text('\$${total1.toStringAsFixed(2)}')),
                      DataCell(Text('\$${total3.toStringAsFixed(2)}')),
                      DataCell(Text('\$${total6.toStringAsFixed(2)}')),
                      DataCell(Text('\$${total6.toStringAsFixed(2)}')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 데이터 클래스들
class CostProjection {
  final LLMModel model;
  final List<MonthlyCost> monthlyCosts;
  final List<double> performanceScores;
  final double efficiencyScores;

  const CostProjection({
    required this.model,
    required this.monthlyCosts,
    required this.performanceScores,
    required this.efficiencyScores,
  });
}

class MonthlyCost {
  final int month;
  final double cost;
  final int usage;

  const MonthlyCost({
    required this.month,
    required this.cost,
    required this.usage,
  });
}