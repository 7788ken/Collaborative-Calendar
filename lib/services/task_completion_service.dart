import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/schedule_data.dart';
import '../data/calendar_book_manager.dart';
import '../data/schedule_service.dart';
import '../models/schedule_item.dart';

/// 统一处理任务完成状态切换的服务类
class TaskCompletionService {
  /// 获取任务的完成状态
  /// 
  /// [context] - BuildContext，用于获取Provider
  /// [schedule] - 要获取状态的日程项
  /// 返回任务的完成状态
  static bool getTaskCompletionStatus(BuildContext context, ScheduleItem schedule) {
    // 创建一个唯一的任务键
    final String taskKey = '${schedule.startTime.year}-${schedule.startTime.month}-${schedule.startTime.day}-${schedule.id}';
    
    // 获取 ScheduleData Provider
    final scheduleData = Provider.of<ScheduleData>(context, listen: false);
    
    // 获取当前状态
    return scheduleData.getTaskCompletionStatus(taskKey);
  }

  /// 切换任务完成状态
  /// 
  /// [context] - BuildContext，用于获取Provider
  /// [schedule] - 要切换状态的日程项
  /// [onStateChanged] - 状态变更后的回调函数
  static Future<void> toggleTaskCompletion(
    BuildContext context, 
    ScheduleItem schedule,
    {VoidCallback? onStateChanged}
  ) async {
    // 捕获当前 BuildContext 的状态和组件引用
    State? state;
    try {
      state = context.findAncestorStateOfType<State>();
      if (state == null || !state.mounted) {
        debugPrint('任务完成状态服务：组件已销毁，取消操作');
        return;
      }
    } catch (e) {
      debugPrint('任务完成状态服务：获取组件状态时出错：$e');
      return;
    }
    
    // 添加振动反馈
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('任务完成状态服务：振动反馈执行失败：$e');
      // 继续执行，这不是关键功能
    }
    
    // 创建一个唯一的任务键
    final String taskKey = '${schedule.startTime.year}-${schedule.startTime.month}-${schedule.startTime.day}-${schedule.id}';
    
    // 捕获当前的 CalendarBookManager 引用，避免在异步操作中多次访问 context
    ScheduleData? scheduleData;
    CalendarBookManager? calendarManager;
    bool? currentStatus;
    
    try {
      // 仅在组件仍然挂载时获取 Provider
      if (!state.mounted) {
        debugPrint('任务完成状态服务：获取Provider前检测到组件已销毁');
        return;
      }
      
      // 安全获取 Provider
      try {
        scheduleData = Provider.of<ScheduleData>(context, listen: false);
        calendarManager = Provider.of<CalendarBookManager>(context, listen: false);
      } catch (e) {
        debugPrint('任务完成状态服务：获取Provider时出错：$e');
        return;
      }
      
      // 获取当前状态
      currentStatus = scheduleData!.getTaskCompletionStatus(taskKey);
      
      // 立即在内存中更新状态
      final newStatus = !currentStatus;
      scheduleData.updateTaskCompletionStatus(taskKey, newStatus);
      
      debugPrint('任务完成状态服务：内存中已更新任务"${schedule.title}"的完成状态为: $newStatus');
      
      // 立即执行回调通知界面刷新，避免等待数据库和网络操作
      if (state.mounted && onStateChanged != null) {
        try {
          onStateChanged();
          debugPrint('任务完成状态服务：已执行初始状态更新回调');
        } catch (e) {
          debugPrint('任务完成状态服务：执行初始状态更新回调时出错：$e');
        }
      }
    } catch (e) {
      debugPrint('任务完成状态服务：更新内存状态过程中出错: $e');
      if (state.mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失败：$e'))
          );
        } catch (e) {
          debugPrint('任务完成状态服务：显示错误提示时出错：$e');
        }
      }
      return;
    }
    
    // 异步执行数据库更新和云同步（脱离UI更新流程）
    _performBackgroundOperations(
      schedule: schedule,
      newStatus: !currentStatus!, 
      calendarManager: calendarManager!,
      state: state
    );
  }
  
  // 执行后台操作（数据库更新和云同步）
  static Future<void> _performBackgroundOperations({
    required ScheduleItem schedule,
    required bool newStatus,
    required CalendarBookManager calendarManager,
    required State state
  }) async {
    debugPrint('任务完成状态服务：开始执行后台任务（数据库更新和云同步）');
    
    try {
      // 更新数据库中的任务完成状态 - 无需依赖UI组件状态
      await _updateScheduleCompletionInDatabase(schedule, newStatus);
      
      // 检查是否需要同步到云端
      if (!state.mounted) {
        debugPrint('任务完成状态服务：组件已销毁，跳过云同步');
        return;
      }
      
      try {
        // 查找对应的日历本
        final calendarBook = calendarManager.books.firstWhere(
          (book) => book.id == schedule.calendarId,
          orElse: () => throw Exception('找不到日历本'),
        );
        
        // 如果是共享日历，则同步到云端
        if (calendarBook.isShared) {
          debugPrint('任务完成状态服务：检测到共享日历的任务状态变更，准备同步到云端...');
          
          // 同步特定任务到云端 - 不依赖UI状态
          try {
            final success = await calendarManager.syncSharedCalendarSchedules(
              schedule.calendarId,
              specificScheduleId: schedule.id
            );
            
            if (success) {
              debugPrint('任务完成状态服务：云端同步成功');
            } else {
              debugPrint('任务完成状态服务：云端同步失败，但本地更新已完成');
            }
          } catch (e) {
            debugPrint('任务完成状态服务：同步到云端时出错: $e');
            // 不抛出异常，避免影响用户体验
          }
        }
      } catch (e) {
        debugPrint('任务完成状态服务：查找日历本或同步过程中出错: $e');
      }
    } catch (e) {
      debugPrint('任务完成状态服务：后台操作执行过程中发生错误: $e');
    }
  }
  
  // 更新数据库中任务的完成状态
  static Future<void> _updateScheduleCompletionInDatabase(ScheduleItem schedule, bool isCompleted) async {
    try {
      // 创建包含新完成状态的日程对象
      final updatedSchedule = schedule.copyWith(isCompleted: isCompleted);
      
      // 使用ScheduleService更新数据库
      final scheduleService = ScheduleService();
      await scheduleService.updateSchedule(updatedSchedule);
      
      debugPrint('任务完成状态服务：成功更新任务完成状态到数据库：${schedule.title}, 完成状态: $isCompleted');
    } catch (e) {
      debugPrint('任务完成状态服务：更新任务完成状态到数据库时出错: $e');
      // 不抛出异常，避免影响用户体验
    }
  }
} 