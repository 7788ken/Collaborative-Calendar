import 'database/database_helper.dart';
import '../models/schedule_item.dart';
import 'calendar_book_manager.dart';
import '../services/api_service.dart';

class ScheduleService {
  static final ScheduleService _instance = ScheduleService._internal();
  factory ScheduleService() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final CalendarBookManager _calendarManager = CalendarBookManager();
  bool _isInitialized = false;

  ScheduleService._internal();

  // 初始化方法
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      print('ScheduleService: 开始初始化...');
      await _calendarManager.init();
      print('ScheduleService: CalendarBookManager 初始化完成');
      print('ScheduleService: 可用的日历本: ${_calendarManager.books.map((b) => '${b.id}:${b.name}').join(', ')}');
      _isInitialized = true;
    }
  }

  // 检查日历本是否存在
  Future<bool> _checkCalendarExists(String calendarId) async {
    await _ensureInitialized();
    print('ScheduleService: 检查日历本是否存在，ID: $calendarId');
    print('ScheduleService: 当前可用的日历本: ${_calendarManager.books.map((b) => '${b.id}:${b.name}').join(', ')}');
    return _calendarManager.books.any((book) => book.id == calendarId);
  }

  // 获取特定日历本的所有日程
  Future<List<ScheduleItem>> getSchedules(String calendarId) async {
    return await _dbHelper.getSchedules(calendarId);
  }

  // 获取日历本中指定日期范围的日程
  Future<List<ScheduleItem>> getSchedulesInRange(String calendarId, DateTime start, DateTime end) async {
    print('ScheduleService: 获取日期范围内的日程');
    print('日历本ID: $calendarId, 开始日期: ${start.toString()}, 结束日期: ${end.toString()}');
    final results = await _dbHelper.getSchedulesInRange(calendarId, start, end);
    print('ScheduleService: 获取到 ${results.length} 条日程数据');
    return results;
  }

  // 获取日历本中指定月份的日程
  Future<List<ScheduleItem>> getSchedulesForMonth(String calendarId, DateTime month) async {
    // 获取月份的第一天和最后一天
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0); // 下个月的第0天就是当前月的最后一天

    return await getSchedulesInRange(calendarId, firstDay, lastDay);
  }

  // 添加日程
  Future<void> addSchedule(ScheduleItem schedule) async {
    try {
      print('ScheduleService: 开始添加日程 ${schedule.title}');

      // 检查日历本是否存在
      if (!await _checkCalendarExists(schedule.calendarId)) {
        throw Exception('未找到ID为 ${schedule.calendarId} 的日历本');
      }

      // 获取日历本信息
      final calendarBook = _calendarManager.books.firstWhere((book) => book.id == schedule.calendarId);

      print('ScheduleService: 找到日历本: ${calendarBook.name}');

      // 如果是共享日历，设置为未同步状态
      final scheduleToSave = calendarBook.isShared ? schedule.copyWith(isSynced: false) : schedule;

      // 保存到数据库
      await _dbHelper.insertSchedule(scheduleToSave);
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
      print('ScheduleService: 日程详情: ${schedule.toMap()}');

      // 确保CalendarBookManager已初始化
      await _ensureInitialized();

      // 获取日历信息
      final calendarBook = _calendarManager.books.firstWhere((book) => book.id == schedule.calendarId, orElse: () => throw Exception('未找到ID为 ${schedule.calendarId} 的日历本'));

      print('ScheduleService: 找到日历本: ${calendarBook.name}');

      // 如果是共享日历，设置为未同步状态
      final scheduleToUpdate = calendarBook.isShared ? schedule.copyWith(isSynced: false) : schedule;

      if (calendarBook.isShared && schedule.isSynced) {
        print('ScheduleService: 日历本是共享的，将日程标记为未同步');
      }

      // 执行本地更新操作
      await _dbHelper.updateSchedule(scheduleToUpdate);
      print('ScheduleService: 日程本地更新成功');

      // 验证更新结果
      final updatedSchedules = await _dbHelper.getScheduleById(schedule.id);
      if (updatedSchedules.isNotEmpty) {
        final updatedSchedule = updatedSchedules.first;
        print('ScheduleService: 验证更新结果: ${updatedSchedule.toMap()}');

        // 检查更新是否成功
        if (updatedSchedule.title != scheduleToUpdate.title || updatedSchedule.startTime != scheduleToUpdate.startTime || updatedSchedule.endTime != scheduleToUpdate.endTime) {
          print('ScheduleService: 警告 - 更新结果与预期不符');
          print('ScheduleService: 预期标题: ${scheduleToUpdate.title}, 实际标题: ${updatedSchedule.title}');
          print('ScheduleService: 预期开始时间: ${scheduleToUpdate.startTime}, 实际开始时间: ${updatedSchedule.startTime}');
          print('ScheduleService: 预期结束时间: ${scheduleToUpdate.endTime}, 实际结束时间: ${updatedSchedule.endTime}');
        } else {
          print('ScheduleService: 更新验证成功，数据已正确保存');
        }
      } else {
        print('ScheduleService: 警告 - 无法验证更新结果，未找到ID为 ${schedule.id} 的日程');
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

  // 更新任务完成状态
  Future<void> updateTaskCompletionStatus(String scheduleId, bool isCompleted) async {
    try {
      print('ScheduleService: 开始更新任务完成状态，ID: $scheduleId, 完成状态: $isCompleted');

      // 获取日程信息
      final schedules = await _dbHelper.getScheduleById(scheduleId);
      if (schedules.isEmpty) {
        print('ScheduleService: 未找到ID为 $scheduleId 的日程');
        return;
      }

      // 保存到数据库
      await _dbHelper.updateScheduleCompletionStatus(scheduleId, isCompleted);
      print('ScheduleService: 任务完成状态更新成功');
    } catch (e) {
      print('ScheduleService: 更新任务完成状态时出错: $e');
      rethrow; // 重新抛出异常以便上层捕获
    }
  }

  // 删除日程
  Future<void> deleteSchedule(String scheduleId) async {
    try {
      print('ScheduleService: 开始删除日程，ID: $scheduleId');

      // 获取日程信息，确保存在
      final schedules = await _dbHelper.getScheduleById(scheduleId);
      if (schedules.isEmpty) {
        print('ScheduleService: 未找到ID为 $scheduleId 的日程，无法删除');
        throw Exception('未找到ID为 $scheduleId 的日程');
      }

      final schedule = schedules.first;
      print('ScheduleService: 找到要删除的日程: ${schedule.title}');

      // 获取日历信息
      await _ensureInitialized();
      final calendarBook = _calendarManager.books.firstWhere((book) => book.id == schedule.calendarId, orElse: () => throw Exception('未找到ID为 ${schedule.calendarId} 的日历本'));

      // 如果是共享日历，可以考虑软删除或标记为需要同步删除
      if (calendarBook.isShared) {
        print('ScheduleService: 日历本是共享的，将执行软删除');
        // 这里可以实现软删除逻辑，例如更新isDeleted字段
        // 暂时使用物理删除
      }

      // 执行删除操作
      await _dbHelper.deleteSchedule(scheduleId);
      print('ScheduleService: 日程删除成功');
    } catch (e) {
      print('ScheduleService: 删除日程时出错: $e');
      rethrow; // 重新抛出异常以便上层捕获
    }
  }
}
