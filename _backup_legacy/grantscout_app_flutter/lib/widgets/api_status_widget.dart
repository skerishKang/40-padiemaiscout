import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ApiStatusWidget extends StatefulWidget {
  const ApiStatusWidget({super.key});

  @override
  State<ApiStatusWidget> createState() => _ApiStatusWidgetState();
}

class _ApiStatusWidgetState extends State<ApiStatusWidget> {
  String _statusMessage = 'API 키 상태 확인 중...';
  Color _statusColor = Colors.grey;
  IconData _statusIcon = Icons.hourglass_empty_outlined;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkApiKeyStatus();
  }

  Future<void> _checkApiKeyStatus() async {
    if (!mounted) return;
    
    setState(() {
      _isChecking = true;
      _statusMessage = 'API 키 상태 확인 중...';
      _statusColor = Colors.grey;
      _statusIcon = Icons.hourglass_empty_outlined;
    });

    try {
      HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('checkApiKeyStatus');
      final result = await callable.call();
      
      if (!mounted) return;
      
      final status = result.data['status'] ?? 'error';
      _updateStatusUI(status);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = '오류: 상태 확인 실패';
        _statusColor = Colors.red;
        _statusIcon = Icons.cancel_outlined;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  void _updateStatusUI(String status) {
    setState(() {
      switch (status) {
        case 'valid':
          _statusMessage = 'API 키 상태: 정상';
          _statusColor = Colors.green;
          _statusIcon = Icons.check_circle_outline;
          break;
        case 'invalid':
          _statusMessage = 'API 키 상태: 확인 필요';
          _statusColor = Colors.red;
          _statusIcon = Icons.error_outline;
          break;
        default:
          _statusMessage = 'API 키 상태: 확인 오류';
          _statusColor = Colors.orange;
          _statusIcon = Icons.warning_amber_outlined;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon, color: _statusColor, size: 18),
          const SizedBox(width: 8),
          Text(
            _statusMessage,
            style: TextStyle(
              color: _statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          _isChecking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: Icon(Icons.refresh, color: _statusColor, size: 18),
                  onPressed: _checkApiKeyStatus,
                  tooltip: 'API 키 상태 새로고침',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
        ],
      ),
    );
  }
}