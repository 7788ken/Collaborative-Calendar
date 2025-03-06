import 'package:flutter/material.dart';
import '../pages/schedule/schedule_page.dart';
import '../pages/task/task_page.dart';
import '../data/calendar_book_manager.dart';
import '../data/models/calendar_book.dart';

class SyncHelper {
  /// 统一的日历同步方法
  /// [context] - BuildContext 用于显示提示和刷新页面
  /// [calendarBook] - 需要同步的日历本
  /// [calendarManager] - 日历管理器实例
  /// 返回值：是否成功同步并有更新
  static Future<bool> syncCalendar({
    required BuildContext context,
    required CalendarBook calendarBook,
    required CalendarBookManager calendarManager,
  }) async {
    if (!context.mounted) return false;
    if (!calendarBook.isShared) return false; // 如果不是共享日历，直接返回

    // 显示同步开始提示
    _showSyncDialog(
      context: context,
      message: '正在检查服务器状态...',
      showLoading: true,
    );

    try {
      // 先检查服务器是否可用
      final isServerAvailable = await calendarManager.checkServerAvailability();
      if (!isServerAvailable) {
        if (!context.mounted) return false;
        _showSyncDialog(
          context: context,
          message: '无法连接到服务器\n请检查服务器是否已启动',
          icon: Icons.cloud_off,
          backgroundColor: Colors.orange,
          showRetryButton: true,
          onRetry: () async {
            await syncCalendar(
              context: context,
              calendarBook: calendarBook,
              calendarManager: calendarManager,
            );
          },
        );
        return false;
      }

      if (!context.mounted) return false;
      // 显示正在同步的提示
      _showSyncDialog(
        context: context,
        message: '正在检查日历更新...',
        showLoading: true,
      );

      // 执行同步操作
      final updated = await calendarManager.checkAndFetchCalendarUpdates(calendarBook.id);
      
      if (!context.mounted) return false;

      // 显示同步结果
      // 获取本地数据库中的最后更新时间
      final updateTime = calendarManager.getLastUpdateTime(calendarBook.id);
      final updateTimeText = formatLastUpdateTime(updateTime);
      
      _showSyncDialog(
        context: context,
        message: updated ? '已更新到最新日历数据\n最后更新: $updateTimeText' : '日历已是最新，无需更新',
        icon: updated ? Icons.check_circle_outline : Icons.info_outline,
        backgroundColor: updated ? Colors.green : Colors.blue,
        autoClose: true,
      );

      // 如果有更新，刷新页面
      if (updated) {
        SchedulePage.refreshSchedules(context);
        TaskPage.refreshTasks(context);
      }

      return updated;
    } catch (error) {
      if (!context.mounted) return false;

      // 处理错误情况
      String errorMessage;
      bool isRetryable = false;
      Color backgroundColor = Colors.red;
      IconData errorIcon = Icons.error_outline;

      // 根据错误类型提供更详细的错误信息
      if (error.toString().contains('Connection refused') ||
          error.toString().contains('SocketException') ||
          error.toString().contains('Failed host lookup')) {
        errorMessage = '无法连接到服务器\n请检查服务器是否已启动';
        isRetryable = true;
        errorIcon = Icons.cloud_off;
        backgroundColor = Colors.orange;
      } else if (error.toString().contains('达到最大重试次数') ||
          error.toString().contains('网络连接错误')) {
        errorMessage = '网络连接不稳定\n请检查网络后重试';
        isRetryable = true;
        errorIcon = Icons.signal_wifi_bad;
        backgroundColor = Colors.orange;
      } else if (error.toString().contains('timeout')) {
        errorMessage = '服务器响应超时\n请检查网络状态后重试';
        isRetryable = true;
        errorIcon = Icons.timer_off;
        backgroundColor = Colors.orange;
      } else if (error.toString().contains('没有检测到更新')) {
        errorMessage = '日历已是最新\n无需更新';
        isRetryable = false;
        errorIcon = Icons.check_circle_outline;
        backgroundColor = Colors.blue;
      } else {
        errorMessage = '同步失败\n${error.toString().split(':').last.trim()}';
        isRetryable = true;
      }

      // 显示错误信息
      _showSyncDialog(
        context: context,
        message: errorMessage,
        icon: errorIcon,
        backgroundColor: backgroundColor,
        showRetryButton: isRetryable,
        onRetry: isRetryable ? () async {
          await syncCalendar(
            context: context,
            calendarBook: calendarBook,
            calendarManager: calendarManager,
          );
        } : null,
      );

      return false;
    }
  }

  /// 统一的同步状态显示方法
  static void _showSyncDialog({
    required BuildContext context,
    required String message,
    IconData? icon,
    bool showLoading = false,
    Color backgroundColor = Colors.blue,
    bool showRetryButton = false,
    VoidCallback? onRetry,
    bool autoClose = false,
  }) {
    // 如果有之前的对话框，先关闭它
    Navigator.of(context).popUntil((route) => route.isFirst);

    final List<String> lines = message.split('\n');
    
    showDialog(
      context: context,
      barrierDismissible: !showLoading, // 加载时不允许点击外部关闭
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else if (icon != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            Text(
              lines[0],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (lines.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  lines[1],
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (showRetryButton && onRetry != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onRetry();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: backgroundColor,
                  ),
                  child: const Text('重试'),
                ),
              ),
          ],
        ),
      ),
    );

    // 如果设置了自动关闭，2秒后自动关闭对话框
    // if (autoClose) {
    //   Future.delayed(const Duration(seconds: 2), () {
    //     if (context.mounted) {
    //       Navigator.of(context).pop(); // 关闭对话框
    //     }
    //   });
    // }
  }

  /// 格式化最后更新时间的显示
  static String formatLastUpdateTime(DateTime? updateTime) {
    if (updateTime == null) return '未同步';
    
    // 格式化为本地时间
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final updateDate = DateTime(updateTime.year, updateTime.month, updateTime.day);

    if (updateDate.isAtSameMomentAs(today)) {
      // 今天更新的，只显示时间
      return '今天 ${updateTime.hour.toString().padLeft(2, '0')}:${updateTime.minute.toString().padLeft(2, '0')}';
    } else if (updateDate.isAfter(today.subtract(const Duration(days: 7)))) {
      // 一周内，显示星期几
      final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      final weekday = weekdays[(updateTime.weekday - 1) % 7];
      return '$weekday ${updateTime.hour.toString().padLeft(2, '0')}:${updateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // 更早的时间，显示完整日期
      return '${updateTime.year}/${updateTime.month.toString().padLeft(2, '0')}/${updateTime.day.toString().padLeft(2, '0')} ${updateTime.hour.toString().padLeft(2, '0')}:${updateTime.minute.toString().padLeft(2, '0')}';
    }
  }
} 