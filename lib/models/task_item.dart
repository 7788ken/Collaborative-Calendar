import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class TaskItem {
  final String id;
  final String calendarId;  // 所属日历本ID
  final String title;
  final bool isCompleted;
  final DateTime? dueDate;
  final DateTime createdAt;

  TaskItem({
    String? id,
    required this.calendarId,
    required this.title,
    this.isCompleted = false,
    this.dueDate,
    DateTime? createdAt,
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now();
  
  // 从Map创建TaskItem对象（用于从数据库读取）
  factory TaskItem.fromMap(Map<String, dynamic> map) {
    return TaskItem(
      id: map['id'],
      calendarId: map['calendar_id'],
      title: map['title'],
      isCompleted: map['is_completed'] == 1,
      dueDate: map['due_date'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['due_date']) 
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }

  // 将TaskItem对象转换为Map（用于存储到数据库）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'calendar_id': calendarId,
      'title': title,
      'is_completed': isCompleted ? 1 : 0,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  // 创建一个具有相同ID和属性的副本，但可以更改部分属性
  TaskItem copyWith({
    String? calendarId,
    String? title,
    bool? isCompleted,
    DateTime? dueDate,
  }) {
    return TaskItem(
      id: this.id,
      calendarId: calendarId ?? this.calendarId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      createdAt: this.createdAt,
    );
  }

  // 切换完成状态
  TaskItem toggleComplete() {
    return copyWith(isCompleted: !isCompleted);
  }
} 