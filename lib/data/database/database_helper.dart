import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';

import '../models/calendar_book.dart';
import '../../models/schedule_item.dart';
import '../../models/task_item.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  
  static Database? _database;
  
  DatabaseHelper._internal();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'calendar_app.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }
  
  Future<void> _createDatabase(Database db, int version) async {
    // 创建日历本表
    await db.execute('''
      CREATE TABLE calendars(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        is_shared INTEGER NOT NULL,
        owner_id TEXT,
        shared_with_users TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    
    // 创建日程表
    await db.execute('''
      CREATE TABLE schedules(
        id TEXT PRIMARY KEY,
        calendar_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        is_all_day INTEGER NOT NULL,
        location TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (calendar_id) REFERENCES calendars (id) ON DELETE CASCADE
      )
    ''');
    
    // 创建任务表
    await db.execute('''
      CREATE TABLE tasks(
        id TEXT PRIMARY KEY,
        calendar_id TEXT NOT NULL,
        title TEXT NOT NULL,
        is_completed INTEGER NOT NULL,
        due_date INTEGER,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (calendar_id) REFERENCES calendars (id) ON DELETE CASCADE
      )
    ''');
    
    // 初始化默认日历本
    await db.insert('calendars', {
      'id': 'default',
      'name': '我的日历',
      'color': Colors.blue.value,
      'is_shared': 0,
      'owner_id': null,
      'shared_with_users': '[]',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  // ==================== 日历本操作 ====================
  
  // 获取所有日历本
  Future<List<CalendarBook>> getCalendarBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('calendars');
    
    return List.generate(maps.length, (i) {
      final map = maps[i];
      // 处理shared_with_users字段，将JSON字符串转换为List<String>
      final sharedWithUsersJson = map['shared_with_users'] as String? ?? '[]';
      final sharedWithUsers = List<String>.from(
        jsonDecode(sharedWithUsersJson) as List<dynamic>
      );
      
      return CalendarBook.fromMap({
        ...map,
        'shared_with_users': sharedWithUsers,
      });
    });
  }
  
  // 插入日历本
  Future<void> insertCalendarBook(CalendarBook book) async {
    final db = await database;
    final bookMap = book.toMap();
    
    // 将shared_with_users转换为JSON字符串
    bookMap['shared_with_users'] = jsonEncode(bookMap['shared_with_users']);
    
    await db.insert(
      'calendars',
      bookMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  // 更新日历本
  Future<void> updateCalendarBook(CalendarBook book) async {
    final db = await database;
    final bookMap = book.toMap();
    
    // 将shared_with_users转换为JSON字符串
    bookMap['shared_with_users'] = jsonEncode(bookMap['shared_with_users']);
    
    await db.update(
      'calendars',
      bookMap,
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }
  
  // 删除日历本
  Future<void> deleteCalendarBook(String id) async {
    final db = await database;
    await db.delete(
      'calendars',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // ==================== 日程操作 ====================
  
  // 获取特定日历本的所有日程
  Future<List<ScheduleItem>> getSchedules(String calendarId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'schedules',
      where: 'calendar_id = ?',
      whereArgs: [calendarId],
    );
    
    return List.generate(maps.length, (i) => ScheduleItem.fromMap(maps[i]));
  }
  
  // 获取日期范围内的日程
  Future<List<ScheduleItem>> getSchedulesInRange(
    String calendarId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      print('DatabaseHelper: 开始获取日期范围内的日程');
      final db = await database;
      final startTime = start.millisecondsSinceEpoch;
      final endTime = end.millisecondsSinceEpoch;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'schedules',
        where: 'calendar_id = ? AND end_time >= ? AND start_time <= ?',
        whereArgs: [calendarId, startTime, endTime],
      );
      
      print('DatabaseHelper: 查询到 ${maps.length} 条日程记录');
      
      final schedules = List.generate(maps.length, (i) => ScheduleItem.fromMap(maps[i]));
      
      // 按日期排序
      schedules.sort((a, b) => a.startTime.compareTo(b.startTime));
      
      return schedules;
    } catch (e) {
      print('DatabaseHelper: 获取日期范围内的日程时出错: $e');
      rethrow;
    }
  }
  
  // 插入日程
  Future<void> insertSchedule(ScheduleItem schedule) async {
    try {
      print('数据库助手: 开始插入日程 ${schedule.title}');
      final db = await database;
      final result = await db.insert(
        'schedules',
        schedule.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('数据库助手: 日程插入成功，结果ID: $result');
    } catch (e) {
      print('数据库助手: 插入日程时出错: $e');
      rethrow; // 重新抛出异常以便上层捕获
    }
  }
  
  // 更新日程
  Future<void> updateSchedule(ScheduleItem schedule) async {
    final db = await database;
    await db.update(
      'schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }
  
  // 删除日程
  Future<void> deleteSchedule(String id) async {
    final db = await database;
    await db.delete(
      'schedules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // ==================== 任务操作 ====================
  
  // 获取特定日历本的所有任务
  Future<List<TaskItem>> getTasks(String calendarId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'calendar_id = ?',
      whereArgs: [calendarId],
    );
    
    return List.generate(maps.length, (i) => TaskItem.fromMap(maps[i]));
  }
  
  // 插入任务
  Future<void> insertTask(TaskItem task) async {
    final db = await database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  // 更新任务
  Future<void> updateTask(TaskItem task) async {
    final db = await database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }
  
  // 删除任务
  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
} 