import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 任务完成状态管理服务
class TaskCompletionService {
  static Future<void> toggleTaskCompletion(BuildContext context, dynamic schedule, {VoidCallback? onStateChanged}) async {
    // 添加振动反馈
    HapticFeedback.lightImpact();
    onStateChanged?.call();
  }
}
