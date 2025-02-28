import 'database/database_helper.dart';
import '../models/schedule_item.dart';
import 'calendar_book_manager.dart';
import '../services/api_service.dart';

class ScheduleService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final CalendarBookManager _calendarManager = CalendarBookManager();
  
  // 获取特定日历本的所有日程
  Future<List<ScheduleItem>> getSchedules(String calendarId) async {
    return await _dbHelper.getSchedules(calendarId);
  }

  // 获取日历本中指定日期范围的日程
  Future<List<ScheduleItem>> getSchedulesInRange(
    String calendarId,
    DateTime start,
    DateTime end,
  ) async {
    print('ScheduleService: 获取日期范围内的日程');
    print('日历本ID: $calendarId, 开始日期: ${start.toString()}, 结束日期: ${end.toString()}');
    final results = await _dbHelper.getSchedulesInRange(calendarId, start, end);
    print('ScheduleService: 获取到 ${results.length} 条日程数据');
    return results;
  }

  // 获取日历本中指定月份的日程
  Future<List<ScheduleItem>> getSchedulesForMonth(
    String calendarId,
    DateTime month,
  ) async {
    // 获取月份的第一天和最后一天
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0); // 下个月的第0天就是当前月的最后一天
    
    return await getSchedulesInRange(calendarId, firstDay, lastDay);
  }

  // 添加日程
  Future<void> addSchedule(ScheduleItem schedule) async {
    try {
      print('ScheduleService: 开始添加日程 ${schedule.title}');
      await _dbHelper.insertSchedule(schedule);
      print('ScheduleService: 日程添加成功');
      
      // 检查是否为共享日历，同步到云端
      await _syncToCloudIfNeeded(schedule.calendarId);
    } catch (e) {
      print('ScheduleService: 添加日程时出错: $e');
      rethrow; // 重新抛出异常以便上层捕获
    }
  }

  // 更新日程
  Future<void> updateSchedule(ScheduleItem schedule) async {
    try {
      print('ScheduleService: 开始更新日程 ${schedule.title}，ID: ${schedule.id}');
      await _dbHelper.updateSchedule(schedule);
      print('ScheduleService: 日程更新成功');
      
      // 检查是否为共享日历，同步到云端
      await _syncToCloudIfNeeded(schedule.calendarId);
    } catch (e) {
      print('ScheduleService: 更新日程时出错: $e');
      rethrow; // 重新抛出异常以便上层捕获
    }
  }

  // 删除日程
  Future<void> deleteSchedule(String id) async {
    try {
      // 先获取日程信息，以获取日历ID
      final schedules = await _dbHelper.getScheduleById(id);
      if (schedules.isEmpty) {
        print('ScheduleService: 未找到ID为 $id 的日程');
        return;
      }
      
      final schedule = schedules.first;
      final calendarId = schedule.calendarId;
      
      // 保存一份删除前的日程信息，用于同步到云端
      final ScheduleItem scheduleToDelete = schedule;
      
      // 执行本地删除操作
      await _dbHelper.deleteSchedule(id);
      print('ScheduleService: 日程(ID:$id)本地删除成功');
      
      // 检查是否为共享日历，如果是则直接同步特定日程到云端
      try {
        // 确保CalendarBookManager已初始化
        if (!_calendarManager.books.any((book) => book.id == calendarId)) {
          await _calendarManager.init();
        }
        
        // 获取日历信息
        final calendarBook = _calendarManager.books.firstWhere(
          (book) => book.id == calendarId,
          orElse: () => throw Exception('未找到ID为 $calendarId 的日历本'),
        );
        
        // 如果是共享日历，则同步删除操作到云端
        if (calendarBook.isShared) {
          print('ScheduleService: 检测到共享日历删除操作，正在同步到云端...');
          print('ScheduleService: 同步单条日程删除，ID: $id');
          
          // 获取分享码
          final shareCode = _calendarManager.getShareId(calendarId);
          if (shareCode == null) {
            throw Exception('未找到日历本的分享码');
          }
          
          // 方法1: 调用API进行软删除 - 通过DELETE请求
          final apiService = ApiService();
          await apiService.deleteSchedule(shareCode, id);
          
          // 方法2: 通过批量同步API发送删除标记，双重确保服务器端标记为已删除
          print('ScheduleService: 通过批量同步API再次确认删除状态');
          await _calendarManager.syncSharedCalendarSchedules(calendarId, specificScheduleId: id);
          
          print('ScheduleService: 云端删除同步完成');
        } else {
          print('ScheduleService: 本地日历，无需同步');
        }
      } catch (e) {
        print('ScheduleService: 同步删除操作到云端时出错: $e');
        // 仅记录错误但不抛出，避免影响主流程
      }
    } catch (e) {
      print('ScheduleService: 删除日程时出错: $e');
      rethrow; // 重新抛出异常以便上层捕获
    }
  }
  
  // 检查日历是否为共享日历，如果是则同步到云端
  Future<void> _syncToCloudIfNeeded(String calendarId) async {
    try {
      // 确保CalendarBookManager已初始化
      if (!_calendarManager.books.any((book) => book.id == calendarId)) {
        await _calendarManager.init();
      }
      
      // 获取日历信息
      final calendarBook = _calendarManager.books.firstWhere(
        (book) => book.id == calendarId,
        orElse: () => throw Exception('未找到ID为 $calendarId 的日历本'),
      );
      
      // 如果是共享日历，则同步到云端
      if (calendarBook.isShared) {
        print('ScheduleService: 检测到共享日历，正在同步到云端...');
        await _calendarManager.syncSharedCalendarSchedules(calendarId);
        print('ScheduleService: 云端同步完成');
      } else {
        print('ScheduleService: 本地日历，无需同步');
      }
    } catch (e) {
      print('ScheduleService: 同步到云端时出错: $e');
      // 仅记录错误但不抛出，避免影响主流程
    }
  }
} 