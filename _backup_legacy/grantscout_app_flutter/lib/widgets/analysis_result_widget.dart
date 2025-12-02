import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';
import '../utils/date_utils.dart';
import '../services/suitability_service.dart';

class AnalysisResultWidget extends StatefulWidget {
  final dynamic analysisResult;
  final String? analysisStatus;
  final String? extractedText;

  const AnalysisResultWidget({
    super.key,
    required this.analysisResult,
    required this.analysisStatus,
    this.extractedText,
  });

  @override
  State<AnalysisResultWidget> createState() => _AnalysisResultWidgetState();
}

class _AnalysisResultWidgetState extends State<AnalysisResultWidget> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final analysisResult = widget.analysisResult;
    final analysisStatus = widget.analysisStatus;
    final extractedText = widget.extractedText;

    Map<String, dynamic>? resultMap;
    String? errorMsg;
    
    if (analysisResult is Map<String, dynamic>) {
      resultMap = analysisResult;
    } else if (analysisResult is String) {
      try {
        resultMap = Map<String, dynamic>.from(
          (analysisResult.trim().startsWith('{'))
              ? (jsonDecode(analysisResult) as Map<String, dynamic>)
              : {},
        );
      } catch (e) {
        errorMsg = '분석 결과를 파싱할 수 없습니다.';
      }
    } else if (analysisResult != null) {
      errorMsg = '지원하지 않는 분석 결과 형식입니다.';
    }

    return _buildStatusBasedUI(analysisStatus, resultMap, errorMsg, extractedText);
  }

  Widget _buildStatusBasedUI(String? status, Map<String, dynamic>? resultMap, String? errorMsg, String? extractedText) {
    if (status == 'processing' || status == 'uploaded' || status == null) {
      return _buildProcessingUI();
    } else if (status == 'analysis_success' && resultMap != null && resultMap.isNotEmpty) {
      return _buildSuccessUI(resultMap, extractedText);
    } else if (status.contains('failed')) {
      return _buildFailedUI(status, extractedText);
    } else if (errorMsg != null) {
      return _buildErrorUI(errorMsg);
    } else {
      return _buildDisabledUI();
    }
  }

  Widget _buildProcessingUI() {
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 8),
        Text('분석 중입니다... (평균 5~10초 소요)'),
      ],
    );
  }

  Widget _buildSuccessUI(Map<String, dynamic> resultMap, String? extractedText) {
    int? elapsedSeconds = _calculateElapsedTime();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDataTable(resultMap),
        if (elapsedSeconds != null) _buildElapsedTimeText(elapsedSeconds),
        _buildSuitabilityButton(resultMap),
        if (extractedText != null && extractedText.isNotEmpty)
          _buildRawResponseButton(extractedText),
      ],
    );
  }

  Widget _buildFailedUI(String status, String? extractedText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('분석 실패: $status', style: const TextStyle(color: Colors.red)),
        if (extractedText != null && extractedText.isNotEmpty)
          _buildRawResponseButton(extractedText),
      ],
    );
  }

  Widget _buildErrorUI(String errorMsg) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(errorMsg, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildDisabledUI() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.analytics, color: Colors.grey),
          label: const Text('분석 완료 후 실행 가능', style: TextStyle(color: Colors.grey)),
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade200,
            disabledBackgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.grey,
            minimumSize: const Size.fromHeight(48),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable(Map<String, dynamic> resultMap) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('항목')),
        DataColumn(label: Text('내용')),
      ],
      rows: _buildDataRows(resultMap),
    );
  }

  List<DataRow> _buildDataRows(Map<String, dynamic> resultMap) {
    final deadlineTimestamp = widget.analysisResult is Map<String, dynamic>
        ? widget.analysisResult['deadlineTimestamp']
        : null;

    final keysToShow = resultMap.keys.where((key) {
      return key != 'deadlineTimestamp' && key != 'deadlineTimestampType';
    }).toList();

    return keysToShow.map((key) {
      final value = resultMap[key];
      String displayValue = value?.toString() ?? '정보 없음';
      
      if (key == '신청기간_종료일' && deadlineTimestamp != null) {
        displayValue = '$displayValue (${DateUtils.buildDeadlineStatus(deadlineTimestamp)})';
      }
      
      return DataRow(cells: [
        DataCell(Text(key)),
        DataCell(SelectableText(displayValue)),
      ]);
    }).toList();
  }

  Widget _buildElapsedTimeText(int elapsedSeconds) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
      child: Text(
        '분석 소요 시간: ${elapsedSeconds}초',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }

  Widget _buildSuitabilityButton(Map<String, dynamic> resultMap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.analytics, color: Colors.white),
          label: _isLoading
              ? const SizedBox.shrink()
              : const Text('적합성 분석 실행', style: TextStyle(color: Colors.white)),
          onPressed: _isLoading ? null : () => _runSuitabilityCheck(resultMap),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            disabledBackgroundColor: Colors.deepPurple.shade100,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildRawResponseButton(String extractedText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        onPressed: () => _showRawResponseDialog(extractedText),
        child: const Text('원본 Gemini 응답 보기'),
      ),
    );
  }

  int? _calculateElapsedTime() {
    try {
      final started = (widget.analysisResult is Map<String, dynamic> &&
              (widget.analysisResult['processingStartedAt'] is Timestamp))
          ? widget.analysisResult['processingStartedAt'] as Timestamp
          : null;
      final ended = (widget.analysisResult is Map<String, dynamic> &&
              (widget.analysisResult['processingEndedAt'] is Timestamp))
          ? widget.analysisResult['processingEndedAt'] as Timestamp
          : null;
      
      if (started != null && ended != null) {
        return ended.seconds - started.seconds;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _runSuitabilityCheck(Map<String, dynamic> resultMap) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await SuitabilityService.checkSuitability(resultMap);
      if (mounted) {
        _showSuitabilityDialog(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('적합성 분석 중 오류: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuitabilityDialog(Map<String, dynamic> result) {
    final suitability = result['suitability'] ?? result['raw'] ?? {};
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('적합성 분석 결과'),
        content: suitability is Map && suitability['score'] != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '점수: ${suitability['score']}점',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text('사유: ${suitability['reason'] ?? '-'}'),
                ],
              )
            : Text(suitability.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showRawResponseDialog(String rawResponse) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('원본 Gemini 응답'),
          content: SingleChildScrollView(
            child: SelectableText(
              rawResponse,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('닫기'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}