import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';

import '../models/calendar_book.dart';
import '../../models/schedule_item.dart';
import '../../models/task_item.dart';

// 本地数据库 用于存储日历本和日程

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

    return await openDatabase(path, version: 3, onCreate: _createDatabase, onUpgrade: _upgradeDatabase);
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    debugPrint('数据库升级: 从版本 $oldVersion 升级到版本 $newVersion');

    if (oldVersion < 2) {
      // 版本1到版本2：添加is_completed列到schedules表
      debugPrint('数据库升级: 为schedules表添加is_completed列');
      try {
        await db.execute('ALTER TABLE schedules ADD COLUMN is_completed INTEGER DEFAULT 0');
        debugPrint('数据库升级: is_completed列添加成功');
      } catch (e) {
        debugPrint('数据库升级失败: $e');
        // 如果列已存在，SQLite会抛出错误，这里我们可以忽略
        if (!e.toString().contains('duplicate column')) {
          rethrow;
        } else {
          debugPrint('数据库升级: is_completed列已存在，跳过');
        }
      }
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
    // 创建日历本表
    await db.execute('''
      CREATE TABLE calendars(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        color INTEGER NOT NULL,
        is_shared INTEGER NOT NULL,
        owner_id TEXT,
        shared_with_users TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        share_code TEXT,
        share_expire_time INTEGER
      )
    ''');

    // 创建日程表
    await db.execute('''
      CREATE TABLE schedules(
        id TEXT PRIMARY KEY,
        calendar_id TEXT NOT NULL, -- 对应日历本ID
        title TEXT NOT NULL,
        description TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        is_all_day INTEGER DEFAULT 0,
        location TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_completed INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 1,
        FOREIGN KEY (calendar_id) REFERENCES calendars (id) ON DELETE CASCADE
      )
    ''');

    // 初始化默认日历本
    await db.insert('calendars', {'id': 'default', 'title': '我的日历', 'color': Colors.blue.value, 'is_shared': 0, 'owner_id': null, 'shared_with_users': '[]', 'created_at': DateTime.now().millisecondsSinceEpoch, 'updated_at': DateTime.now().millisecondsSinceEpoch, 'share_code': null, 'share_expire_time': null});
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
      final sharedWithUsers = List<String>.from(jsonDecode(sharedWithUsersJson) as List<dynamic>);

      return CalendarBook.fromMap({...map, 'shared_with_users': sharedWithUsers});
    });
  }

  // 插入日历本
  Future<void> insertCalendarBook(CalendarBook book) async {
    final db = await database;
    final bookMap = book.toMap();

    // 将shared_with_users转换为JSON字符串
    bookMap['shared_with_users'] = jsonEncode(bookMap['shared_with_users']);

    await db.insert('calendars', bookMap, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // 更新日历本
  Future<void> updateCalendarBook(CalendarBook book) async {
    final db = await database;
    final bookMap = book.toMap();

    // 将shared_with_users转换为JSON字符串
    bookMap['shared_with_users'] = jsonEncode(bookMap['shared_with_users']);

    await db.update('calendars', bookMap, where: 'id = ?', whereArgs: [book.id]);
  }

  // 删除日历本
  Future<void> deleteCalendarBook(String id) async {
    final db = await database;
    await db.delete('calendars', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== 日程操作 ====================

  // 获取特定日历本的所有日程
  Future<List<ScheduleItem>> getSchedules(String calendarId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('schedules', where: 'calendar_id = ?', whereArgs: [calendarId]);

    return List.generate(maps.length, (i) => ScheduleItem.fromMap(maps[i]));
  }

  // 获取日期范围内的日程
  Future<List<ScheduleItem>> getSchedulesInRange(String calendarId, DateTime start, DateTime end) async {
    try {
      debugPrint('DatabaseHelper: 开始获取日期范围内的日程');
      final db = await database;
      final startTime = start.millisecondsSinceEpoch;
      final endTime = end.millisecondsSinceEpoch;

      final List<Map<String, dynamic>> maps = await db.query('schedules', where: 'calendar_id = ? AND end_time >= ? AND start_time <= ?', whereArgs: [calendarId, startTime, endTime]);
      try {
        debugPrint('DatabaseHelper: 查询到 ${maps.length} 条日程记录');
      } catch (e) {
        debugPrint('DatabaseHelper: 查询日程时出错: $e');
      }

      final schedules = List.generate(maps.length, (i) => ScheduleItem.fromMap(maps[i]));

      // 按日期排序
      schedules.sort((a, b) => a.startTime.compareTo(b.startTime));

      return schedules;
    } catch (e) {
      debugPrint('DatabaseHelper: 获取日期范围内的日程时出错: $e');
      rethrow;
    }
  }

  // 插入日程
  Future<void> insertSchedule(ScheduleItem schedule) async {
    try {
      final db = await database;
      final result = await db.insert('schedules', schedule.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('DatabaseHelper: 插入日程时出错: $e');
      rethrow; // 重新抛出异常以便上层捕获
    }
  }

  // 更新日程
  Future<void> updateSchedule(ScheduleItem schedule) async {
    try {
      debugPrint('DatabaseHelper: 开始更新日程 ${schedule.title}，ID: ${schedule.id}');
      debugPrint('DatabaseHelper: 日程所属日历本ID: ${schedule.calendarId}');
      debugPrint('DatabaseHelper: 更新的日程详情：${schedule.toMap()}');

      final db = await database;

      // 开始事务
      await db.transaction((txn) async {
        // 查询原始记录，用于比较
        final originalRecords = await txn.query('schedules', where: 'id = ?', whereArgs: [schedule.id]);

        if (originalRecords.isNotEmpty) {
          final originalCalendarId = originalRecords.first['calendar_id'];
          debugPrint('DatabaseHelper: 原始日程所属日历本ID: $originalCalendarId');
          debugPrint('DatabaseHelper: 新日程所属日历本ID: ${schedule.calendarId}');

          if (originalCalendarId != schedule.calendarId) {
            debugPrint('DatabaseHelper: 警告! 日历本ID发生变化! 原ID=$originalCalendarId, 新ID=${schedule.calendarId}');

            // 验证新的日历本是否存在
            final calendarExists = await txn.query('calendars', where: 'id = ?', whereArgs: [schedule.calendarId]);

            if (calendarExists.isEmpty) {
              throw Exception('目标日历本不存在: ${schedule.calendarId}');
            }
          }

          // 更新记录
          final updateCount = await txn.update('schedules', schedule.toMap(), where: 'id = ?', whereArgs: [schedule.id]);

          debugPrint('DatabaseHelper: 更新操作影响的记录数: $updateCount');

          if (updateCount == 0) {
            throw Exception('更新失败：没有记录被修改');
          }
        } else {
          debugPrint('DatabaseHelper: 未找到原始记录，尝试插入新记录');

          // 验证日历本是否存在
          final calendarExists = await txn.query('calendars', where: 'id = ?', whereArgs: [schedule.calendarId]);

          if (calendarExists.isEmpty) {
            throw Exception('目标日历本不存在: ${schedule.calendarId}');
          }

          // 插入新记录
          final insertResult = await txn.insert('schedules', schedule.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

          debugPrint('DatabaseHelper: 插入新记录成功，ID: $insertResult');
        }
      });

      // 验证更新结果
      final verifyResult = await db.query('schedules', where: 'id = ?', whereArgs: [schedule.id]);

      if (verifyResult.isEmpty) {
        throw Exception('更新后无法找到记录: ${schedule.id}');
      }

      debugPrint('DatabaseHelper: 日程更新成功，最终结果: ${verifyResult.first}');
    } catch (e) {
      debugPrint('DatabaseHelper: 更新日程时出错: $e');
      rethrow;
    }
  }

  // 删除日程
  Future<void> deleteSchedule(String id) async {
    final db = await database;
    await db.delete('schedules', where: 'id = ?', whereArgs: [id]);
  }

  // 根据ID获取日程
  Future<List<ScheduleItem>> getScheduleById(String id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('schedules', where: 'id = ?', whereArgs: [id]);

      if (maps.isEmpty) {
        debugPrint('DatabaseHelper: 未找到ID为 $id 的日程');
        return [];
      }

      return List.generate(maps.length, (i) => ScheduleItem(id: maps[i]['id'], calendarId: maps[i]['calendar_id'], title: maps[i]['title'], description: maps[i]['description'], startTime: DateTime.fromMillisecondsSinceEpoch(maps[i]['start_time']), endTime: DateTime.fromMillisecondsSinceEpoch(maps[i]['end_time']), isAllDay: maps[i]['is_all_day'] == 1, location: maps[i]['location'], isCompleted: maps[i]['is_completed'] == 1));
    } catch (e) {
      debugPrint('DatabaseHelper: 根据ID获取日程时出错: $e');
      return [];
    }
  }

  // 获取最近修改的日程
  Future<List<ScheduleItem>> getRecentlyModifiedSchedules(String calendarId) async {
    try {
      debugPrint('DatabaseHelper: 开始获取最近修改的日程');

      // 检查数据库中是否有sync_status列
      final db = await database;
      var hasColumn = false;

      try {
        final result = await db.rawQuery('PRAGMA table_info(schedules)');
        hasColumn = result.any((column) => column['name'] == 'sync_status');
      } catch (e) {
        debugPrint('DatabaseHelper: 检查表结构时出错: $e');
      }

      // 如果没有sync_status列，添加它
      if (!hasColumn) {
        debugPrint('DatabaseHelper: 添加sync_status列');
        await db.execute('ALTER TABLE schedules ADD COLUMN sync_status INTEGER DEFAULT 0');
      }

      // 获取所有需要同步的日程（sync_status = 0或null）
      final List<Map<String, dynamic>> maps = await db.query('schedules', where: 'calendar_id = ? AND (sync_status = 0 OR sync_status IS NULL)', whereArgs: [calendarId]);

      debugPrint('DatabaseHelper: 找到 ${maps.length} 条需要同步的日程');

      return List.generate(maps.length, (i) => ScheduleItem.fromMap(maps[i]));
    } catch (e) {
      debugPrint('DatabaseHelper: 获取最近修改的日程时出错: $e');
      return [];
    }
  }

  // 更新日程同步状态
  Future<void> updateScheduleSyncStatus(String scheduleId, bool synced) async {
    try {
      debugPrint('DatabaseHelper: 更新日程同步状态, ID: $scheduleId, 状态: ${synced ? '已同步' : '未同步'}');

      final db = await database;

      // 检查数据库中是否有sync_status列
      var hasColumn = false;
      try {
        final result = await db.rawQuery('PRAGMA table_info(schedules)');
        hasColumn = result.any((column) => column['name'] == 'sync_status');
      } catch (e) {
        debugPrint('DatabaseHelper: 检查表结构时出错: $e');
      }

      // 如果没有sync_status列，添加它
      if (!hasColumn) {
        debugPrint('DatabaseHelper: 添加sync_status列');
        await db.execute('ALTER TABLE schedules ADD COLUMN sync_status INTEGER DEFAULT 0');
      }

      // 更新同步状态
      final updateCount = await db.update('schedules', {'sync_status': synced ? 1 : 0}, where: 'id = ?', whereArgs: [scheduleId]);

      debugPrint('DatabaseHelper: 同步状态更新成功，更新了 $updateCount 条记录');
    } catch (e) {
      debugPrint('DatabaseHelper: 更新日程同步状态时出错: $e');
    }
  }

  // 获取未同步的日程
  Future<List<ScheduleItem>> getUnsyncedSchedules(String calendarId) async {
    try {
      debugPrint('DatabaseHelper: 开始获取未同步的日程');
      final db = await database;

      final List<Map<String, dynamic>> maps = await db.query('schedules', where: 'calendar_id = ? AND sync_status = 0', whereArgs: [calendarId]);

      debugPrint('DatabaseHelper: 找到 ${maps.length} 条未同步的日程');
      return List.generate(maps.length, (i) => ScheduleItem.fromMap(maps[i]));
    } catch (e) {
      debugPrint('DatabaseHelper: 获取未同步的日程时出错: $e');
      return [];
    }
  }

  // ==================== 任务操作 ====================

  // 获取特定日历本的所有任务
  Future<List<TaskItem>> getTasks(String calendarId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tasks', where: 'calendar_id = ?', whereArgs: [calendarId]);

    return List.generate(maps.length, (i) => TaskItem.fromMap(maps[i]));
  }

  // 插入任务
  Future<void> insertTask(TaskItem task) async {
    final db = await database;
    await db.insert('tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // 更新任务
  Future<void> updateTask(TaskItem task) async {
    final db = await database;
    await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  // 删除任务
  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // 删除特定日历本中的所有日程
  Future<int> deleteAllSchedulesInCalendar(String calendarId) async {
    try {
      final db = await database;
      final count = await db.delete('schedules', where: 'calendar_id = ?', whereArgs: [calendarId]);

      debugPrint('DatabaseHelper: 已删除日历 $calendarId 中的 $count 条日程');
      return count;
    } catch (e) {
      debugPrint('DatabaseHelper: 删除日历中所有日程时出错: $e');
      rethrow;
    }
  }
}
