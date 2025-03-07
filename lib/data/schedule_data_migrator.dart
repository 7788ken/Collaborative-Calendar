import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'schedule_data.dart' as old_data;
import '../models/schedule_item.dart';
import 'schedule_service.dart';
import 'database/database_helper.dart';
import 'calendar_book_manager.dart';
import 'package:uuid/uuid.dart';

// 数据迁移工具，用于将测试数据迁移到数据库
class ScheduleDataMigrator {
  static const String _migrationKey = 'test_data_migrated';
  final ScheduleService _scheduleService = ScheduleService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // 检查是否已经迁移过测试数据
  Future<bool> _isMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_migrationKey) ?? false;
  }
  
  // 标记迁移完成
  Future<void> _markMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migrationKey, true);
  }
  
  // 如果需要则执行迁移
  Future<void> migrateIfNeeded() async {
    final isMigrated = await _isMigrated();
    if (!isMigrated) {
      await migrateTestData();
      await _markMigrated();
    }
  }
  
  // 迁移测试数据到数据库
  Future<void> migrateTestData() async {
    try {
      // 获取默认日历本ID
      final calendarManager = CalendarBookManager();
      await calendarManager.init();
      final defaultCalendarId = calendarManager.activeBook?.id;
      
      if (defaultCalendarId == null) {
        print('未找到默认日历本，无法迁移测试数据');
        return;
      }
      
      // 获取测试数据
      final testData = old_data.ScheduleData.scheduleItems;
      
      // 处理每个测试数据条目
      for (var oldItem in testData) {
        // 获取日期
        final date = oldItem.date;
        
        // 解析开始时间和结束时间
        final startTimeParts = oldItem.startTime.split(':');
        final endTimeParts = oldItem.endTime.split(':');
        
        final startHour = int.parse(startTimeParts[0]);
        final startMinute = int.parse(startTimeParts[1]);
        final endHour = int.parse(endTimeParts[0]);
        final endMinute = int.parse(endTimeParts[1]);
        
        // 创建新的ScheduleItem对象
        final newSchedule = ScheduleItem(
          id: const Uuid().v4(),
          calendarId: defaultCalendarId,
          title: oldItem.title.isNotEmpty ? oldItem.title : '未命名日程',
          description: oldItem.remark,
          startTime: DateTime(date.year, date.month, date.day, startHour, startMinute),
          endTime: DateTime(date.year, date.month, date.day, endHour, endMinute),
          isAllDay: false,
          location: oldItem.location,
          isSynced: false, // 新迁移的数据标记为未同步
        );
        
        try {
          // 保存到数据库
          await _scheduleService.addSchedule(newSchedule);
          print('成功迁移日程: ${newSchedule.title}');
        } catch (e) {
          print('迁移日程时出错: ${newSchedule.title}, 错误: $e');
          continue; // 继续处理下一条数据
        }
      }
      
      print('测试数据迁移完成');
    } catch (e) {
      print('迁移测试数据时出错: $e');
    }
  }
} 