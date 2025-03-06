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
      
      // 执行本地更新操作
      await _dbHelper.updateSchedule(schedule);
      print('ScheduleService: 日程本地更新成功');
      
      // 检查是否为共享日历，如果是则直接使用API更新到云端
      try {
        // 确保CalendarBookManager已初始化
        if (!_calendarManager.books.any((book) => book.id == schedule.calendarId)) {
          await _calendarManager.init();
        }
        
        // 获取日历信息
        final calendarBook = _calendarManager.books.firstWhere(
          (book) => book.id == schedule.calendarId,
          orElse: () => throw Exception('未找到ID为 ${schedule.calendarId} 的日历本'),
        );
        
        // 如果是共享日历，则使用API直接更新到云端
        if (calendarBook.isShared) {
          print('ScheduleService: 检测到共享日历更新操作，正在同步到云端...');
          
          // 获取分享码
          final shareCode = _calendarManager.getShareId(schedule.calendarId);
          if (shareCode == null) {
            throw Exception('未找到日历本的分享码');
          }
          
          // 使用正确的API接口更新日程
          print('ScheduleService: 使用API接口更新日程，shareCode=$shareCode, scheduleId=${schedule.id}');
          final apiService = ApiService();
          await apiService.updateSchedule(shareCode, schedule.id, schedule);
          
          print('ScheduleService: 云端更新同步完成');
        } else {
          print('ScheduleService: 本地日历，无需同步');
        }
      } catch (e) {
        print('ScheduleService: 同步更新操作到云端时出错: $e');
        // 仅记录错误但不抛出，避免影响主流程
      }
    } catch (e) {
      print('ScheduleService: 更新日程时出错: $e');
      rethrow; // 重新抛出异常以便上层捕获
    }
  }

  // 根据ID获取日程
  Future<List<ScheduleItem>> getScheduleById(String id) async {
    try {
      print('ScheduleService: 通过ID查询日程, ID=$id');
      return await _dbHelper.getScheduleById(id);
    } catch (e) {
      print('ScheduleService: 根据ID查询日程时出错: $e');
      return [];
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
      
      // 执行本地删除操作
      await _dbHelper.deleteSchedule(id);
      print('ScheduleService: 日程(ID:$id)本地删除成功');
      
      // 检查是否为共享日历，如果是则同步删除到云端
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
          
          // 获取分享码
          final shareCode = _calendarManager.getShareId(calendarId);
          if (shareCode == null) {
            throw Exception('未找到日历本的分享码');
          }
          
          // 使用正确的API接口删除日程
          print('ScheduleService: 使用API接口删除日程，shareCode=$shareCode, scheduleId=$id');
          final apiService = ApiService();
          await apiService.deleteSchedule(shareCode, id);
          
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
      print('ScheduleService: 开始检查是否需要同步到云端，日历ID: $calendarId');
      
      // 确保CalendarBookManager已初始化
      if (!_calendarManager.books.any((book) => book.id == calendarId)) {
        print('ScheduleService: CalendarBookManager未初始化，正在初始化...');
        await _calendarManager.init();
      }
      
      // 获取日历信息
      final calendarBook = _calendarManager.books.firstWhere(
        (book) => book.id == calendarId,
        orElse: () => throw Exception('未找到ID为 $calendarId 的日历本'),
      );
      
      print('ScheduleService: 找到日历本: ${calendarBook.name}, 是否共享: ${calendarBook.isShared}');
      
      // 如果是共享日历，则同步到云端
      if (calendarBook.isShared) {
        print('ScheduleService: 检测到共享日历，正在同步到云端...');
        
        // 获取分享码
        final shareCode = _calendarManager.getShareId(calendarId);
        print('ScheduleService: 获取到分享码: $shareCode');
        
        if (shareCode == null) {
          throw Exception('未找到日历本的分享码');
        }
        
        // 获取最新添加的日程数据（最后一条）
        final schedules = await _dbHelper.getSchedules(calendarId);
        print('ScheduleService: 获取到 ${schedules.length} 条日程');
        
        if (schedules.isEmpty) {
          print('ScheduleService: 没有需要同步的日程');
          return;
        }
        
        // 只同步最新添加的日程（最后一条）
        final latestSchedule = schedules.last;
        print('ScheduleService: 同步最新添加的日程: ${latestSchedule.title}, ID: ${latestSchedule.id}');
        print('ScheduleService: 日程详情: 开始时间=${latestSchedule.startTime}, 结束时间=${latestSchedule.endTime}, 全天=${latestSchedule.isAllDay}');
        
        // 使用API服务直接添加日程
        final apiService = ApiService();
        try {
          print('ScheduleService: 开始调用API添加日程...');
          final result = await apiService.addSchedule(shareCode, latestSchedule);
          print('ScheduleService: 日程 ${latestSchedule.title} 同步到云端成功, 结果: $result');
          
          // 更新日程的同步状态
          await _dbHelper.updateScheduleSyncStatus(latestSchedule.id, true);
          print('ScheduleService: 已更新日程同步状态为已同步');
        } catch (e) {
          print('ScheduleService: 同步日程 ${latestSchedule.title} 到云端失败: $e');
        }
        
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