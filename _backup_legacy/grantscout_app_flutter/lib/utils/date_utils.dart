import 'package:cloud_firestore/cloud_firestore.dart';

class DateUtils {
  static String buildDeadlineStatus(dynamic deadlineTimestamp) {
    if (deadlineTimestamp == null) {
      return '마감일 정보 없음';
    }
    
    try {
      final deadline = (deadlineTimestamp is Timestamp)
          ? deadlineTimestamp.toDate()
          : (deadlineTimestamp is DateTime)
              ? deadlineTimestamp
              : null;
              
      if (deadline == null) return '마감일 정보 오류';
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final deadlineDate = DateTime(deadline.year, deadline.month, deadline.day);
      final diff = deadlineDate.difference(today);
      final days = diff.inDays;
      final formattedDeadline = "${deadlineDate.year}.${deadlineDate.month.toString().padLeft(2, '0')}.${deadlineDate.day.toString().padLeft(2, '0')}";
      
      if (days > 0) {
        return '마감 D-$days ($formattedDeadline)';
      } else if (days == 0) {
        return '🚨 오늘 마감! ($formattedDeadline)';
      } else {
        return '마감일 지남 (${-days}일 경과, $formattedDeadline)';
      }
    } catch (e) {
      return '마감일 오류';
    }
  }
}