import 'database/database_helper.dart';
import '../models/schedule_item.dart';

class ScheduleService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
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
    return await _dbHelper.getSchedulesInRange(calendarId, start, end);
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
    await _dbHelper.insertSchedule(schedule);
  }

  // 更新日程
  Future<void> updateSchedule(ScheduleItem schedule) async {
    await _dbHelper.updateSchedule(schedule);
  }

  // 删除日程
  Future<void> deleteSchedule(String id) async {
    await _dbHelper.deleteSchedule(id);
  }
} 