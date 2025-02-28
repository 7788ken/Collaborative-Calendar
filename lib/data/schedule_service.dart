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
    } catch (e) {
      print('ScheduleService: 更新日程时出错: $e');
      rethrow; // 重新抛出异常以便上层捕获
    }
  }

  // 删除日程
  Future<void> deleteSchedule(String id) async {
    await _dbHelper.deleteSchedule(id);
  }
} 