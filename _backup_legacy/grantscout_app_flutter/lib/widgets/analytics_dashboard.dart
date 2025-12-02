import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:charts_flutter_new/flutter.dart' as charts;
import '../utils/performance_monitor.dart';

class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _analyticsData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    PerformanceMonitor.startMeasurement('analytics_dashboard_load');

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 분석 데이터 수집
        final data = await _collectAnalyticsData(user.uid);
        if (mounted) {
          setState(() {
            _analyticsData = data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } finally {
      PerformanceMonitor.endMeasurement('analytics_dashboard_load');
    }
  }

  Future<Map<String, dynamic>> _collectAnalyticsData(String userId) async {
    // 파일 분석 트렌드
    final filesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('files')
        .orderBy('uploadedAt', descending: true)
        .limit(100)
        .get();

    // 지원사업 매칭 데이터
    final matchesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('grant_matches')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    // 활동 로그
    final activitySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('activity_logs')
        .orderBy('timestamp', descending: true)
        .limit(200)
        .get();

    return {
      'files': _processFileData(filesSnapshot.docs),
      'matches': _processMatchData(matchesSnapshot.docs),
      'activities': _processActivityData(activitySnapshot.docs),
      'summary': _calculateSummary(filesSnapshot.docs, matchesSnapshot.docs),
    };
  }

  Map<String, dynamic> _processFileData(List<DocumentSnapshot> docs) {
    final monthlyData = <String, int>{};
    final categoryData = <String, int>{};
    final statusData = <String, int>{};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final uploadedAt = data['uploadedAt'] as Timestamp?;
      final category = data['category'] as String? ?? '기타';
      final status = data['analysisStatus'] as String? ?? '미분석';

      if (uploadedAt != null) {
        final month = '${uploadedAt.toDate().year}-${uploadedAt.toDate().month.toString().padLeft(2, '0')}';
        monthlyData[month] = (monthlyData[month] ?? 0) + 1;
      }

      categoryData[category] = (categoryData[category] ?? 0) + 1;
      statusData[status] = (statusData[status] ?? 0) + 1;
    }

    return {
      'monthly': monthlyData,
      'categories': categoryData,
      'status': statusData,
    };
  }

  Map<String, dynamic> _processMatchData(List<DocumentSnapshot> docs) {
    final monthlyMatches = <String, int>{};
    final successRate = <String, double>{};
    int totalMatches = docs.length;
    int successfulMatches = 0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = data['createdAt'] as Timestamp?;
      final suitabilityScore = (data['suitabilityScore'] as num?)?.toDouble() ?? 0.0;

      if (createdAt != null) {
        final month = '${createdAt.toDate().year}-${createdAt.toDate().month.toString().padLeft(2, '0')}';
        monthlyMatches[month] = (monthlyMatches[month] ?? 0) + 1;
      }

      if (suitabilityScore >= 70.0) {
        successfulMatches++;
      }
    }

    // 월별 성공률 계산
    monthlyMatches.forEach((month, count) {
      final monthSuccessful = docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) return false;

        final docMonth = '${createdAt.toDate().year}-${createdAt.toDate().month.toString().padLeft(2, '0')}';
        if (docMonth != month) return false;

        final score = (data['suitabilityScore'] as num?)?.toDouble() ?? 0.0;
        return score >= 70.0;
      }).length;

      successRate[month] = count > 0 ? (monthSuccessful / count) * 100 : 0.0;
    });

    return {
      'monthly': monthlyMatches,
      'successRate': successRate,
      'total': totalMatches,
      'successful': successfulMatches,
      'overallSuccessRate': totalMatches > 0 ? (successfulMatches / totalMatches) * 100 : 0.0,
    };
  }

  Map<String, dynamic> _processActivityData(List<DocumentSnapshot> docs) {
    final dailyActivity = <String, int>{};
    final activityTypes = <String, int>{};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp?;
      final type = data['type'] as String? ?? '기타';

      if (timestamp != null) {
        final day = timestamp.toDate().toIso8601String().substring(0, 10);
        dailyActivity[day] = (dailyActivity[day] ?? 0) + 1;
      }

      activityTypes[type] = (activityTypes[type] ?? 0) + 1;
    }

    return {
      'daily': dailyActivity,
      'types': activityTypes,
    };
  }

  Map<String, dynamic> _calculateSummary(List<DocumentSnapshot> files, List<DocumentSnapshot> matches) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);

    final thisMonthFiles = files.where((doc) {
      final uploadedAt = (doc.data() as Map<String, dynamic>)['uploadedAt'] as Timestamp?;
      return uploadedAt != null && uploadedAt.toDate().isAfter(thisMonth);
    }).length;

    final thisMonthMatches = matches.where((doc) {
      final createdAt = (doc.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      return createdAt != null && createdAt.toDate().isAfter(thisMonth);
    }).length;

    final highScoreMatches = matches.where((doc) {
      final score = ((doc.data() as Map<String, dynamic>)['suitabilityScore'] as num?)?.toDouble() ?? 0.0;
      return score >= 80.0;
    }).length;

    return {
      'totalFiles': files.length,
      'totalMatches': matches.length,
      'thisMonthFiles': thisMonthFiles,
      'thisMonthMatches': thisMonthMatches,
      'highScoreMatches': highScoreMatches,
      'averageMatchScore': _calculateAverageScore(matches),
    };
  }

  double _calculateAverageScore(List<DocumentSnapshot> matches) {
    if (matches.isEmpty) return 0.0;

    final totalScore = matches.fold<double>(0.0, (sum, doc) {
      final score = ((doc.data() as Map<String, dynamic>)['suitabilityScore'] as num?)?.toDouble() ?? 0.0;
      return sum + score;
    });

    return totalScore / matches.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('분석 대시보드'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: '개요'),
            Tab(icon: Icon(Icons.trending_up), text: '트렌드'),
            Tab(icon: Icon(Icons.pie_chart), text: '분석'),
            Tab(icon: Icon(Icons.insights), text: '인사이트'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildTrendsTab(),
                _buildAnalysisTab(),
                _buildInsightsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final summary = _analyticsData['summary'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSummaryCards(summary),
          const SizedBox(height: 20),
          _buildQuickStats(),
          const SizedBox(height: 20),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                '총 파일',
                '${summary['totalFiles'] ?? 0}',
                Icons.insert_drive_file,
                Colors.blue,
                '이번 달: +${summary['thisMonthFiles'] ?? 0}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                '매칭 결과',
                '${summary['totalMatches'] ?? 0}',
                Icons.compare_arrows,
                Colors.green,
                '이번 달: +${summary['thisMonthMatches'] ?? 0}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                '고득점 매칭',
                '${summary['highScoreMatches'] ?? 0}',
                Icons.star,
                Colors.amber,
                '80점 이상',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                '평균 점수',
                '${(summary['averageMatchScore'] as double? ?? 0.0).toStringAsFixed(1)}',
                Icons.analytics,
                Colors.purple,
                '최대 100점',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final files = _analyticsData['files'] as Map<String, dynamic>? ?? {};
    final matches = _analyticsData['matches'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '빠른 통계',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '파일 상태',
                    files['status'] as Map<String, dynamic>? ?? {},
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildStatItem(
                    '카테고리',
                    files['categories'] as Map<String, dynamic>? ?? {},
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, Map<String, dynamic> data, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        ...data.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '${entry.value}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final activities = _analyticsData['activities'] as Map<String, dynamic>? ?? {};
    final dailyData = activities['daily'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '최근 활동',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (dailyData.isEmpty)
              const Text('활동 데이터가 없습니다.')
            else
              Column(
                children: dailyData.entries.take(7).map((entry) {
                  return ListTile(
                    leading: const Icon(Icons.circle, size: 8),
                    title: Text('${entry.value}개 활동'),
                    subtitle: Text(entry.key),
                    dense: true,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildFileUploadTrend(),
          const SizedBox(height: 20),
          _buildMatchTrend(),
        ],
      ),
    );
  }

  Widget _buildFileUploadTrend() {
    final files = _analyticsData['files'] as Map<String, dynamic>? ?? {};
    final monthlyData = files['monthly'] as Map<String, dynamic>? ?? {};

    if (monthlyData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('파일 업로드 트렌드 데이터가 없습니다.')),
        ),
      );
    }

    final series = [
      charts.Series<Map<String, dynamic>, String>(
        id: '월별 파일 업로드',
        data: monthlyData.entries.map((entry) => {
          'month': entry.key,
          'count': entry.value,
        }).toList(),
        domainFn: (data, _) => data['month'] as String,
        measureFn: (data, _) => data['count'] as int,
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '월별 파일 업로드 트렌드',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: charts.BarChart(
                series,
                animate: true,
                vertical: false,
                barRendererDecorator: charts.BarLabelDecorator<String>(),
                domainAxis: const charts.OrdinalAxisSpec(
                  renderSpec: charts.NoneRenderSpec(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchTrend() {
    final matches = _analyticsData['matches'] as Map<String, dynamic>? ?? {};
    final monthlyData = matches['monthly'] as Map<String, dynamic>? ?? {};

    if (monthlyData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('매칭 트렌드 데이터가 없습니다.')),
        ),
      );
    }

    final series = [
      charts.Series<Map<String, dynamic>, String>(
        id: '월별 매칭',
        data: monthlyData.entries.map((entry) => {
          'month': entry.key,
          'count': entry.value,
        }).toList(),
        domainFn: (data, _) => data['month'] as String,
        measureFn: (data, _) => data['count'] as int,
        colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '월별 매칭 트렌드',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: charts.LineChart(
                series,
                animate: true,
                defaultRenderer: charts.LineRendererConfig(
                  includePoints: true,
                  radiusPx: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCategoryAnalysis(),
          const SizedBox(height: 20),
          _buildSuccessRateAnalysis(),
        ],
      ),
    );
  }

  Widget _buildCategoryAnalysis() {
    final files = _analyticsData['files'] as Map<String, dynamic>? ?? {};
    final categoryData = files['categories'] as Map<String, dynamic>? ?? {};

    if (categoryData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('카테고리 데이터가 없습니다.')),
        ),
      );
    }

    final series = [
      charts.Series<Map<String, dynamic>, String>(
        id: '파일 카테고리',
        data: categoryData.entries.map((entry) => {
          'category': entry.key,
          'count': entry.value,
        }).toList(),
        domainFn: (data, _) => data['category'] as String,
        measureFn: (data, _) => data['count'] as int,
        colorFn: (data, index) {
          final colors = [
            charts.MaterialPalette.blue.shadeDefault,
            charts.MaterialPalette.green.shadeDefault,
            charts.MaterialPalette.red.shadeDefault,
            charts.MaterialPalette.yellow.shadeDefault,
            charts.MaterialPalette.purple.shadeDefault,
          ];
          return colors[index! % colors.length];
        },
        labelAccessorFn: (data, _) => '${data['category']}: ${data['count']}',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '파일 카테고리 분석',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: charts.PieChart(
                series,
                animate: true,
                defaultRenderer: charts.ArcRendererConfig(
                  arcWidth: 60,
                  arcRendererDecorators: [charts.ArcLabelDecorator()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessRateAnalysis() {
    final matches = _analyticsData['matches'] as Map<String, dynamic>? ?? {};
    final successRateData = matches['successRate'] as Map<String, dynamic>? ?? {};

    if (successRateData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('성공률 데이터가 없습니다.')),
        ),
      );
    }

    final series = [
      charts.Series<Map<String, dynamic>, String>(
        id: '월별 성공률',
        data: successRateData.entries.map((entry) => {
          'month': entry.key,
          'rate': entry.value,
        }).toList(),
        domainFn: (data, _) => data['month'] as String,
        measureFn: (data, _) => data['rate'] as double,
        colorFn: (_, __) => charts.MaterialPalette.purple.shadeDefault,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '월별 성공률 분석 (70점 이상)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: charts.LineChart(
                series,
                animate: true,
                behaviors: [
                  charts.ChartTitle(
                    '성공률 (%)',
                    behaviorPosition: charts.BehaviorPosition.start,
                    titleOutsideJustification: charts.OutsideJustification.middleDrawArea,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildKeyInsights(),
          const SizedBox(height: 20),
          _buildRecommendations(),
        ],
      ),
    );
  }

  Widget _buildKeyInsights() {
    final summary = _analyticsData['summary'] as Map<String, dynamic>? ?? {};
    final matches = _analyticsData['matches'] as Map<String, dynamic>? ?? {};

    final insights = <String>[];

    // 인사이트 생성
    final totalFiles = summary['totalFiles'] as int? ?? 0;
    final totalMatches = summary['totalMatches'] as int? ?? 0;
    final avgScore = summary['averageMatchScore'] as double? ?? 0.0;
    final overallSuccessRate = matches['overallSuccessRate'] as double? ?? 0.0;

    if (totalFiles > 10) {
      insights.add('📈 활발한 사용자: 총 ${totalFiles}개의 파일을 분석했습니다.');
    }

    if (avgScore >= 70.0) {
      insights.add('🎯 높은 매칭 품질: 평균 ${avgScore.toStringAsFixed(1)}점의 매칭 점수를 기록했습니다.');
    } else if (avgScore > 0) {
      insights.add('💡 매칭 품질 개선 필요: 평균 점수 ${avgScore.toStringAsFixed(1)}점. 더 구체적인 키워드를 사용해보세요.');
    }

    if (overallSuccessRate >= 50.0) {
      insights.add('✅ 우수한 성공률: ${overallSuccessRate.toStringAsFixed(1)}%의 높은 매칭 성공률을 보입니다.');
    }

    if (insights.isEmpty) {
      insights.add('📊 데이터가 축적되면 개인화된 인사이트를 제공합니다.');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '주요 인사이트',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '맞춤 추천',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRecommendationItem(
              '🔍 키워드 최적화',
              '더 구체적인 산업 키워드를 사용하여 매칭 정확도를 높여보세요.',
              Icons.trending_up,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildRecommendationItem(
              '📅 정기적인 업데이트',
              '최신 지원사업 정보를 계속 확인하고 새로운 기회를 놓치지 마세요.',
              Icons.update,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildRecommendationItem(
              '🤝 AI 모델 실험',
              '다양한 AI 모델을 사용해보시고 가장 적합한 분석 결과를 찾아보세요.',
              Icons.psychology,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationItem(String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}