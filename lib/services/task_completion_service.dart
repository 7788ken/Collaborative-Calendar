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
    // 添加振动反馈
    HapticFeedback.lightImpact();
    
    // 创建一个唯一的任务键
    final String taskKey = '${schedule.startTime.year}-${schedule.startTime.month}-${schedule.startTime.day}-${schedule.id}';
    
    // 获取 ScheduleData Provider
    final scheduleData = Provider.of<ScheduleData>(context, listen: false);
    
    // 获取当前状态
    final currentStatus = scheduleData.getTaskCompletionStatus(taskKey);
    
    // 更新为相反的状态
    final newStatus = !currentStatus;
    scheduleData.updateTaskCompletionStatus(taskKey, newStatus);
    
    // 更新数据库中的任务完成状态
    await _updateScheduleCompletionInDatabase(schedule, newStatus);
    
    // 获取日历管理器判断是否需要同步到云端
    final calendarManager = Provider.of<CalendarBookManager>(context, listen: false);
    try {
      final calendarBook = calendarManager.books.firstWhere(
        (book) => book.id == schedule.calendarId,
        orElse: () => throw Exception('找不到日历本'),
      );
      
      // 如果是共享日历，则同步到云端
      if (calendarBook.isShared) {
        print('任务完成状态服务：检测到共享日历的任务状态变更，准备同步到云端...');
        try {
          // 只同步被修改的特定任务，而不是所有任务
          await calendarManager.syncSharedCalendarSchedules(
            schedule.calendarId,
            specificScheduleId: schedule.id
          );
          print('任务完成状态服务：云端同步完成');
        } catch (e) {
          print('任务完成状态服务：同步到云端时出错: $e');
          // 但不显示错误，避免影响用户体验
        }
      }
    } catch (e) {
      print('获取日历本信息时出错: $e');
    }
    
    // 调用状态变更回调
    if (onStateChanged != null) {
      onStateChanged();
    }
    
    print('任务"${schedule.title}"的完成状态已切换为: $newStatus, 键值: $taskKey');
  }
  
  // 更新数据库中任务的完成状态
  static Future<void> _updateScheduleCompletionInDatabase(ScheduleItem schedule, bool isCompleted) async {
    try {
      // 创建包含新完成状态的日程对象
      final updatedSchedule = schedule.copyWith(isCompleted: isCompleted);
      
      // 使用ScheduleService更新数据库
      final scheduleService = ScheduleService();
      await scheduleService.updateSchedule(updatedSchedule);
      
      print('任务完成状态服务：成功更新任务完成状态到数据库：${schedule.title}, 完成状态: $isCompleted');
    } catch (e) {
      print('任务完成状态服务：更新任务完成状态到数据库时出错: $e');
      // 不抛出异常，避免影响用户体验
    }
  }
} 