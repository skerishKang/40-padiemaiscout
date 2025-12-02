import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/offline_provider.dart';
import '../utils/network_checker.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        if (offlineProvider.networkStatus == NetworkStatus.online) {
          // 온라인이지만 처리할 작업이 있는 경우
          if (offlineProvider.isProcessingQueue && offlineProvider.pendingActionsCount > 0) {
            return _buildProcessingBanner(context, offlineProvider);
          }
          return const SizedBox.shrink();
        }

        // 오프라인 상태
        return _buildOfflineBanner(context, offlineProvider);
      },
    );
  }

  Widget _buildOfflineBanner(BuildContext context, OfflineProvider offlineProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.orange.shade100,
      child: Row(
        children: [
          Icon(
            Icons.wifi_off,
            color: Colors.orange.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '오프라인 모드',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                if (offlineProvider.pendingActionsCount > 0)
                  Text(
                    '${offlineProvider.pendingActionsCount}개 작업이 대기 중입니다',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade600,
                    ),
                  ),
              ],
            ),
          ),
          if (offlineProvider.pendingActionsCount > 0)
            IconButton(
              icon: Icon(
                Icons.list,
                color: Colors.orange.shade700,
                size: 20,
              ),
              onPressed: () => _showOfflineQueueDialog(context, offlineProvider),
              tooltip: '대기 중인 작업 보기',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  Widget _buildProcessingBanner(BuildContext context, OfflineProvider offlineProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.blue.shade100,
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.blue.shade700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '오프라인 작업 동기화 중... (${offlineProvider.pendingActionsCount}개 남음)',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOfflineQueueDialog(BuildContext context, OfflineProvider offlineProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대기 중인 작업'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (offlineProvider.pendingActions.isEmpty)
                const Text('대기 중인 작업이 없습니다.')
              else
                ...offlineProvider.pendingActions.map((item) => ListTile(
                  leading: _getActionIcon(item.action),
                  title: Text(_getActionTitle(item.action)),
                  subtitle: Text(
                    '${item.timestamp.toString().substring(0, 19)} (${item.retryCount}회 재시도)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () {
                      offlineProvider.removeAction(item.id);
                      Navigator.of(context).pop();
                    },
                  ),
                )),
            ],
          ),
        ),
        actions: [
          if (offlineProvider.pendingActions.isNotEmpty) ...[
            TextButton(
              onPressed: () {
                offlineProvider.clearQueue();
                Navigator.of(context).pop();
              },
              child: const Text('모두 제거'),
            ),
            if (offlineProvider.isOnline)
              TextButton(
                onPressed: () {
                  offlineProvider.retryPendingActions();
                  Navigator.of(context).pop();
                },
                child: const Text('재시도'),
              ),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Icon _getActionIcon(OfflineAction action) {
    switch (action) {
      case OfflineAction.profileUpdate:
        return const Icon(Icons.person, size: 20);
      case OfflineAction.fileUpload:
        return const Icon(Icons.upload_file, size: 20);
      case OfflineAction.analysisRequest:
        return const Icon(Icons.analytics, size: 20);
      case OfflineAction.suitabilityCheck:
        return const Icon(Icons.check_circle, size: 20);
      case OfflineAction.none:
        return const Icon(Icons.help_outline, size: 20);
    }
  }

  String _getActionTitle(OfflineAction action) {
    switch (action) {
      case OfflineAction.profileUpdate:
        return '프로필 업데이트';
      case OfflineAction.fileUpload:
        return '파일 업로드';
      case OfflineAction.analysisRequest:
        return '분석 요청';
      case OfflineAction.suitabilityCheck:
        return '적합성 검사';
      case OfflineAction.none:
        return '알 수 없는 작업';
    }
  }
}

// 네트워크 상태 표시 위젯
class NetworkStatusIndicator extends StatelessWidget {
  const NetworkStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        Color color;
        IconData icon;
        
        switch (offlineProvider.networkStatus) {
          case NetworkStatus.online:
            color = Colors.green;
            icon = Icons.wifi;
            break;
          case NetworkStatus.offline:
            color = Colors.red;
            icon = Icons.wifi_off;
            break;
          case NetworkStatus.unknown:
            color = Colors.grey;
            icon = Icons.help_outline;
            break;
        }

        return Tooltip(
          message: offlineProvider.networkStatusMessage,
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        );
      },
    );
  }
}