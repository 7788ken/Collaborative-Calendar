import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ScheduleItem {
  final String id;
  final String calendarId;  // 所属日历本ID
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String? location;
  final DateTime createdAt;
  final bool isCompleted; // 添加任务完成状态字段

  ScheduleItem({
    String? id,
    required this.calendarId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.location,
    DateTime? createdAt,
    this.isCompleted = false, // 默认为未完成
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now();
  
  // 从Map创建ScheduleItem对象（用于从数据库读取）
  factory ScheduleItem.fromMap(Map<String, dynamic> map) {
    return ScheduleItem(
      id: map['id'],
      calendarId: map['calendar_id'],
      title: map['title'],
      description: map['description'],
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time']),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['end_time']),
      isAllDay: map['is_all_day'] == 1,
      location: map['location'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      isCompleted: map['is_completed'] == 1, // 从数据库读取完成状态
    );
  }

  // 将ScheduleItem对象转换为Map（用于存储到数据库）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'calendar_id': calendarId,
      'title': title,
      'description': description,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'is_all_day': isAllDay ? 1 : 0,
      'location': location,
      'created_at': createdAt.millisecondsSinceEpoch,
      'is_completed': isCompleted ? 1 : 0, // 存储完成状态
    };
  }

  // 创建一个具有相同ID和属性的副本，但可以更改部分属性
  ScheduleItem copyWith({
    String? calendarId,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    String? location,
    bool? isCompleted, // 添加完成状态字段
  }) {
    return ScheduleItem(
      id: this.id,
      calendarId: calendarId ?? this.calendarId,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      location: location ?? this.location,
      createdAt: this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted, // 保留完成状态
    );
  }

  // 判断日程是否在指定日期
  bool isOnDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startDateOnly = DateTime(startTime.year, startTime.month, startTime.day);
    final endDateOnly = DateTime(endTime.year, endTime.month, endTime.day);
    
    return (dateOnly.isAtSameMomentAs(startDateOnly) || 
            dateOnly.isAtSameMomentAs(endDateOnly) ||
            (dateOnly.isAfter(startDateOnly) && dateOnly.isBefore(endDateOnly)));
  }
  
  // 切换任务完成状态
  ScheduleItem toggleComplete() {
    return copyWith(isCompleted: !isCompleted);
  }
} 