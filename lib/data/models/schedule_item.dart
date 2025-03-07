import 'package:flutter/material.dart';
import '../../models/schedule_item.dart' as calendar_models;
import 'package:uuid/uuid.dart';

class ScheduleItem {
  final String title;
  final String startTime;
  final String endTime;
  final String location;
  final String remark;
  final DateTime date;
  bool isCompleted;
  final bool isSynced;

  ScheduleItem({
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.remark,
    required this.date,
    this.isCompleted = false,
    this.isSynced = true,
  });
  
  // 将任务项转换为日历日程项
  calendar_models.ScheduleItem toCalendarSchedule({
    required String calendarId,
    String? id,
  }) {
    print('将任务项转换为日历日程项，使用指定的日历本ID: $calendarId');
    final scheduleId = id ?? const Uuid().v4(); // 如果 id 为空，生成新的 UUID
    return calendar_models.ScheduleItem(
      id: scheduleId,
      calendarId: calendarId,
      title: title,
      description: remark,
      startTime: DateTime(
        date.year,
        date.month,
        date.day,
        int.tryParse(startTime.split(':')[0]) ?? 0,
        int.tryParse(startTime.split(':')[1]) ?? 0,
      ),
      endTime: DateTime(
        date.year,
        date.month,
        date.day,
        int.tryParse(endTime.split(':')[0]) ?? 0,
        int.tryParse(endTime.split(':')[1]) ?? 0,
      ),
      location: location,
      isSynced: isSynced,
    );
  }

  // 创建已完成状态切换的副本
  ScheduleItem toggleComplete() {
    return ScheduleItem(
      title: title,
      startTime: startTime,
      endTime: endTime,
      location: location,
      remark: remark,
      date: date,
      isCompleted: !isCompleted,
      isSynced: isSynced,
    );
  }
} 