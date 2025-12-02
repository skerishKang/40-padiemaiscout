import 'package:flutter/material.dart';
import '../models/llm_model.dart';
import '../services/model_performance_service.dart';

class LLMModelComparison extends StatefulWidget {
  final LLMModel? currentModel;
  final Function(LLMModel) onModelSelected;

  const LLMModelComparison({
    super.key,
    this.currentModel,
    required this.onModelSelected,
  });

  @override
  State<LLMModelComparison> createState() => _LLMModelComparisonState();
}

class _LLMModelComparisonState extends State<LLMModelComparison> {
  List<LLMModel> _models = [];
  Map<String, ModelPerformance> _performanceData = {};
  String _selectedUseCase = 'grant_analysis';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadModelsAndPerformance();
  }

  Future<void> _loadModelsAndPerformance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _models = LLMModel.getAllModels();

      // 각 모델의 성능 데이터 로드
      for (final model in _models) {
        final performance = await ModelPerformanceService.getModelPerformance(
          modelId: model.id,
          useCase: _selectedUseCase,
        );
        _performanceData[model.id] = performance;
      }
    } catch (e) {
      // 에러 처리
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'AI 모델 비교 분석',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildUseCaseSelector(),
            const SizedBox(height: 16),
            _buildComparisonTable(),
            const SizedBox(height: 16),
            _buildDetailedComparison(),
          ],
        ),
      ),
    );
  }

  Widget _buildUseCaseSelector() {
    final useCases = [
      {'id': 'grant_analysis', 'name': '지원사업 분석', 'icon': Icons.analytics},
      {'id': 'document_summary', 'name': '문서 요약', 'icon': Icons.summarize},
      {'id': 'korean_understanding', 'name': '한글 이해도', 'icon': Icons.translate},
      {'id': 'code_generation', 'name': '코드 생성', 'icon': Icons.code},
      {'id': 'creative_writing', 'name': '창의 글쓰기', 'icon': Icons.create},
      {'id': 'data_analysis', 'name': '데이터 분석', 'icon': Icons.insights},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '사용 목적 선택',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: useCases.map((useCase) {
            final isSelected = _selectedUseCase == useCase['id'];
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(useCase['icon'] as IconData, size: 16),
                  const SizedBox(width: 4),
                  Text(useCase['name'] as String),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedUseCase = useCase['id'] as String;
                  });
                  _loadModelsAndPerformance();
                }
              },
              backgroundColor: isSelected
                  ? Theme.of(context).primaryColor.withOpacity(0.2)
                  : null,
              selectedColor: Theme.of(context).primaryColor,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildComparisonTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(
            label: Text('모델'),
            tooltip: 'AI 모델 이름',
          ),
          DataColumn(
            label: Text('정확도'),
            tooltip: '해당 사용 목적의 정확도',
          ),
          DataColumn(
            label: Text('속도'),
            tooltip: '응답 속도 (초)',
          ),
          DataColumn(
            label: Text('비용'),
            tooltip: '1000 토큰당 비용',
          ),
          DataColumn(
            label: Text('한글'),
            tooltip: '한글 처리 능력',
          ),
          DataColumn(
            label: Text('점수'),
            tooltip: '종합 평가 점수',
          ),
        ],
        rows: _models.map((model) {
          final performance = _performanceData[model.id] ?? ModelPerformance.empty();
          return DataRow(
            selected: widget.currentModel?.id == model.id,
            onSelectChanged: (selected) {
              if (selected) {
                widget.onModelSelected(model);
              }
            },
            cells: [
              DataCell(
                Row(
                  children: [
                    _getModelIcon(model.provider),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        model.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(
                _buildAccuracyCell(performance.accuracy),
              ),
              DataCell(
                _buildSpeedCell(performance.averageResponseTime),
              ),
              DataCell(
                _buildCostCell(model.costPerToken),
              ),
              DataCell(
                _buildKoreanCell(model),
              ),
              DataCell(
                _buildScoreCell(performance.overallScore),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailedComparison() {
    return ExpansionTile(
      title: const Text(
        '상세 비교 정보',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        const SizedBox(height: 16),
        _buildCapabilityComparison(),
        const SizedBox(height: 16),
        _buildUseCaseRecommendation(),
        const SizedBox(height: 16),
        _buildCostAnalysis(),
      ],
    );
  }

  Widget _buildCapabilityComparison() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '역량별 비교',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ..._models.map((model) {
            final performance = _performanceData[model.id] ?? ModelPerformance.empty();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _getModelIcon(model.provider),
                      const SizedBox(width: 8),
                      Text(
                        model.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: model.capabilities.map((capability) {
                      final score = _getCapabilityScore(performance, capability);
                      return Chip(
                        label: Text(capability),
                        backgroundColor: _getCapabilityColor(score),
                        labelStyle: TextStyle(
                          color: score > 0.7 ? Colors.white : Colors.black,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildUseCaseRecommendation() {
    final recommendation = _getRecommendedModel();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text(
                '이 사용 목적에 추천',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recommendation != null) ...[
            Row(
              children: [
                _getModelIcon(recommendation.model.provider),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recommendation.model.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '추천',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              recommendation.reason,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: recommendation.strengths.map((strength) {
                return Chip(
                  label: Text(strength),
                  backgroundColor: Colors.green[100],
                  labelStyle: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            const Text('데이터를 분석 중입니다...'),
          ],
        ],
      ),
    );
  }

  Widget _buildCostAnalysis() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '비용 효율 분석',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            '100만 토큰 처리 시 예상 비용:',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          ..._models.map((model) {
            final cost = model.costPerToken * 1000000;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _getModelIcon(model.provider),
                      const SizedBox(width: 8),
                      Text(model.name),
                    ],
                  ),
                  Text(
                    '\$${cost.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _getCostColor(cost),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 12),
          Text(
            '* 실제 비용은 사용량에 따라 다를 수 있습니다.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getModelIcon(LLMProvider provider) {
    switch (provider) {
      case LLMProvider.gemini:
        return Image.asset('assets/icons/google.png', width: 20, height: 20);
      case LLMProvider.openai:
        return Image.asset('assets/icons/openai.png', width: 20, height: 20);
      case LLMProvider.claude:
        return Image.asset('assets/icons/anthropic.png', width: 20, height: 20);
      case LLMProvider.clovaX:
        return Image.asset('assets/icons/naver.png', width: 20, height: 20);
      default:
        return Icon(Icons.psychology, size: 20);
    }
  }

  Widget _buildAccuracyCell(double accuracy) {
    final color = _getAccuracyColor(accuracy);
    return Row(
      children: [
        Container(
          width: 50,
          height: 8,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: accuracy,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(accuracy * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedCell(double responseTime) {
    final color = _getSpeedColor(responseTime);
    return Text(
      '${responseTime.toStringAsFixed(1)}s',
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildCostCell(double cost) {
    return Text(
      '\$${cost.toStringAsFixed(4)}',
      style: TextStyle(
        color: _getCostColor(cost),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildKoreanCell(LLMModel model) {
    final koreanScore = _getKoreanScore(model);
    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            return Icon(
              index < koreanScore ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 16,
            );
          }),
        ),
        const SizedBox(width: 4),
        Text(
          '($koreanScore/5)',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCell(double score) {
    final color = _getScoreColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.9) return Colors.green;
    if (accuracy >= 0.8) return Colors.blue;
    if (accuracy >= 0.7) return Colors.orange;
    return Colors.red;
  }

  Color _getSpeedColor(double responseTime) {
    if (responseTime <= 1.0) return Colors.green;
    if (responseTime <= 2.0) return Colors.blue;
    if (responseTime <= 5.0) return Colors.orange;
    return Colors.red;
  }

  Color _getCostColor(double cost) {
    if (cost <= 5.0) return Colors.green;
    if (cost <= 15.0) return Colors.blue;
    if (cost <= 30.0) return Colors.orange;
    return Colors.red;
  }

  Color _getScoreColor(double score) {
    if (score >= 8.5) return Colors.green;
    if (score >= 7.5) return Colors.blue;
    if (score >= 6.5) return Colors.orange;
    return Colors.red;
  }

  int _getKoreanScore(LLMModel model) {
    switch (model.provider) {
      case LLMProvider.clovaX:
        return 5; // 네이버 - 한글 최적화
      case LLMProvider.gemini:
        return 4; // 구글 - 한글 지원 우수
      case LLMProvider.claude:
        return 3; // 앤스로픽 - 한글 지원 양호
      case LLMProvider.openai:
        return 3; // OpenAI - 한글 지원 보통
      default:
        return 2;
    }
  }

  double _getCapabilityScore(ModelPerformance performance, String capability) {
    // 실제 성능 데이터 기반 역량 점수 계산
    switch (capability.toLowerCase()) {
      case 'text':
        return performance.textAccuracy;
      case 'code':
        return performance.codeAccuracy;
      case 'analysis':
        return performance.analysisAccuracy;
      case 'korean':
        return performance.koreanAccuracy;
      default:
        return 0.7;
    }
  }

  Color _getCapabilityColor(double score) {
    if (score >= 0.8) return Colors.green[100]!;
    if (score >= 0.6) return Colors.blue[100]!;
    if (score >= 0.4) return Colors.orange[100]!;
    return Colors.red[100]!;
  }

  ModelRecommendation? _getRecommendedModel() {
    double bestScore = 0.0;
    LLMModel? bestModel;

    for (final model in _models) {
      final performance = _performanceData[model.id] ?? ModelPerformance.empty();

      // 사용 목적에 따라 가중치 다르게 적용
      double score = 0.0;

      switch (_selectedUseCase) {
        case 'grant_analysis':
          score = performance.overallScore * 0.6 +
                  performance.analysisAccuracy * 0.3 +
                  performance.koreanAccuracy * 0.1;
          break;
        case 'korean_understanding':
          score = performance.koreanAccuracy * 0.7 +
                  performance.overallScore * 0.3;
          break;
        case 'code_generation':
          score = performance.codeAccuracy * 0.6 +
                  performance.overallScore * 0.4;
          break;
        default:
          score = performance.overallScore;
      }

      if (score > bestScore) {
        bestScore = score;
        bestModel = model;
      }
    }

    if (bestModel != null) {
      final performance = _performanceData[bestModel.id] ?? ModelPerformance.empty();
      return ModelRecommendation(
        model: bestModel,
        reason: _getRecommendationReason(bestModel, performance),
        strengths: _getStrengths(bestModel, performance),
      );
    }

    return null;
  }

  String _getRecommendationReason(LLMModel model, ModelPerformance performance) {
    switch (_selectedUseCase) {
      case 'grant_analysis':
        return '지원사업 분석에 최적화된 모델입니다. 분석 정확도 ${(performance.analysisAccuracy * 100).toStringAsFixed(1)}%';
      case 'korean_understanding':
        return '한글 이해도가 가장 뛰어난 모델입니다. 한글 처리 정확도 ${(performance.koreanAccuracy * 100).toStringAsFixed(1)}%';
      case 'code_generation':
        return '코드 생성 능력이 뛰어난 모델입니다. 코드 정확도 ${(performance.codeAccuracy * 100).toStringAsFixed(1)}%';
      default:
        return '종합 성능이 가장 우수한 모델입니다. 전체 점수 ${performance.overallScore.toStringAsFixed(1)}점';
    }
  }

  List<String> _getStrengths(LLMModel model, ModelPerformance performance) {
    final strengths = <String>[];

    if (performance.accuracy >= 0.85) {
      strengths.add('높은 정확도');
    }
    if (performance.averageResponseTime <= 2.0) {
      strengths.add('빠른 응답 속도');
    }
    if (model.costPerToken <= 0.01) {
      strengths.add('저렴한 비용');
    }
    if (_getKoreanScore(model) >= 4) {
      strengths.add('한글 최적화');
    }

    return strengths;
  }
}

class ModelPerformance {
  final double accuracy;
  final double textAccuracy;
  final double codeAccuracy;
  final double analysisAccuracy;
  final double koreanAccuracy;
  final double averageResponseTime;
  final double overallScore;

  const ModelPerformance({
    this.accuracy = 0.0,
    this.textAccuracy = 0.0,
    this.codeAccuracy = 0.0,
    this.analysisAccuracy = 0.0,
    this.koreanAccuracy = 0.0,
    this.averageResponseTime = 0.0,
    this.overallScore = 0.0,
  });

  factory ModelPerformance.empty() {
    return const ModelPerformance();
  }
}

class ModelRecommendation {
  final LLMModel model;
  final String reason;
  final List<String> strengths;

  const ModelRecommendation({
    required this.model,
    required this.reason,
    required this.strengths,
  });
}