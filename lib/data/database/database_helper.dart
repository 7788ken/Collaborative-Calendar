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

    return await openDatabase(path, version: 7, onCreate: _createDatabase, onUpgrade: _upgradeDatabase);
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

    if (oldVersion < 2) {
      // 版本1到版本2的迁移：添加创建时间和更新时间字段
      try {
        await db.execute('ALTER TABLE calendars ADD COLUMN createdAt INTEGER');
        await db.execute('ALTER TABLE calendars ADD COLUMN updatedAt INTEGER');

        // 为现有记录设置默认值
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.execute('UPDATE calendars SET createdAt = $now, updatedAt = $now WHERE createdAt IS NULL');
      } catch (e) {
        print('迁移数据库时出错: $e');
      }
    }

    // 修复sharedWithUsers列类型问题
    if (oldVersion < 3) {
      try {
        // 检查列是否存在
        var columns = await db.rawQuery('PRAGMA table_info(calendars)');
        bool hasSharedWithUsers = columns.any((column) => column['name'] == 'sharedWithUsers');

        // 如果列已存在但类型不对，需要迁移数据
        if (hasSharedWithUsers) {
          // 创建临时表
          await db.execute('''
            CREATE TABLE calendars_temp(
              id TEXT PRIMARY KEY,
              name TEXT,
              color INTEGER,
              isShared INTEGER,
              ownerId TEXT,
              sharedWithUsers TEXT,
              createdAt INTEGER,
              updatedAt INTEGER
            )
          ''');

          // 将数据复制到临时表
          await db.execute('''
            INSERT INTO calendars_temp 
            SELECT id, name, color, isShared, ownerId, 
                   '[]', -- 初始化为空JSON数组
                   COALESCE(createdAt, ${DateTime.now().millisecondsSinceEpoch}),
                   COALESCE(updatedAt, ${DateTime.now().millisecondsSinceEpoch})
            FROM calendars
          ''');

          // 删除原表并重命名临时表
          await db.execute('DROP TABLE calendars');
          await db.execute('ALTER TABLE calendars_temp RENAME TO calendars');
        }
        // 如果列不存在，添加它
        else {
          await db.execute('ALTER TABLE calendars ADD COLUMN sharedWithUsers TEXT DEFAULT "[]"');
        }
      } catch (e) {
        print('迁移sharedWithUsers列时出错: $e');
      }
    }

    // 添加shareCode字段到calendars表
    if (oldVersion < 4) {
      debugPrint('数据库升级: 为calendars表添加shareCode列');
      try {
        // 检查shareCode列是否已存在
        var columns = await db.rawQuery('PRAGMA table_info(calendars)');
        bool hasShareCode = columns.any((column) => column['name'] == 'shareCode');

        if (!hasShareCode) {
          await db.execute('ALTER TABLE calendars ADD COLUMN shareCode TEXT');
          debugPrint('数据库升级: shareCode列添加成功');
        } else {
          debugPrint('数据库升级: shareCode列已存在，跳过');
        }
      } catch (e) {
        debugPrint('数据库升级失败: $e');
        // 如果出现错误，但不是列已存在的错误，则重新抛出
        if (!e.toString().contains('duplicate column')) {
          rethrow;
        }
      }
    }

    // 添加updated_at字段到schedules表
    if (oldVersion < 5) {
      debugPrint('数据库升级: 为schedules表添加updated_at列');
      try {
        // 检查updated_at列是否已存在
        var columns = await db.rawQuery('PRAGMA table_info(schedules)');
        bool hasUpdatedAt = columns.any((column) => column['name'] == 'updated_at');

        if (!hasUpdatedAt) {
          await db.execute('ALTER TABLE schedules ADD COLUMN updated_at INTEGER');
          // 为现有记录设置默认值
          final now = DateTime.now().millisecondsSinceEpoch;
          await db.execute('UPDATE schedules SET updated_at = $now');
          debugPrint('数据库升级: updated_at列添加成功');
        } else {
          debugPrint('数据库升级: updated_at列已存在，跳过');
        }
      } catch (e) {
        debugPrint('数据库升级失败: $e');
        // 如果出现错误，但不是列已存在的错误，则重新抛出
        if (!e.toString().contains('duplicate column')) {
          rethrow;
        }
      }
    }

    // 添加sync_status字段到schedules表
    if (oldVersion < 6) {
      debugPrint('数据库升级: 为schedules表添加sync_status列');
      try {
        // 检查sync_status列是否已存在
        var columns = await db.rawQuery('PRAGMA table_info(schedules)');
        bool hasSyncStatus = columns.any((column) => column['name'] == 'sync_status');

        if (!hasSyncStatus) {
          await db.execute('ALTER TABLE schedules ADD COLUMN sync_status INTEGER DEFAULT 1');
          debugPrint('数据库升级: sync_status列添加成功');
        } else {
          debugPrint('数据库升级: sync_status列已存在，跳过');
        }
      } catch (e) {
        debugPrint('数据库升级失败: $e');
        // 如果出现错误，但不是列已存在的错误，则重新抛出
        if (!e.toString().contains('duplicate column')) {
          rethrow;
        }
      }
    }

    // 添加is_deleted字段到schedules表
    if (oldVersion < 7) {
      debugPrint('数据库升级: 为schedules表添加is_deleted列');
      try {
        // 检查is_deleted列是否已存在
        var columns = await db.rawQuery('PRAGMA table_info(schedules)');
        bool hasIsDeleted = columns.any((column) => column['name'] == 'is_deleted');

        if (!hasIsDeleted) {
          await db.execute('ALTER TABLE schedules ADD COLUMN is_deleted INTEGER DEFAULT 0');
          debugPrint('数据库升级: is_deleted列添加成功');
        } else {
          debugPrint('数据库升级: is_deleted列已存在，跳过');
        }
      } catch (e) {
        debugPrint('数据库升级失败: $e');
        // 如果出现错误，但不是列已存在的错误，则重新抛出
        if (!e.toString().contains('duplicate column')) {
          rethrow;
        }
      }
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
    // 创建日历本表
    await db.execute('''
      CREATE TABLE calendars(
        id TEXT PRIMARY KEY,
        name TEXT,
        color INTEGER,
        isShared INTEGER,
        ownerId TEXT,
        sharedWithUsers TEXT,
        createdAt INTEGER,
        updatedAt INTEGER,
        shareCode TEXT
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
    await db.insert('calendars', {'id': 'default', 'name': '我的日历', 'color': Colors.blue.value, 'isShared': 0, 'ownerId': null, 'sharedWithUsers': '[]', 'createdAt': DateTime.now().millisecondsSinceEpoch, 'updatedAt': DateTime.now().millisecondsSinceEpoch});
  }

  // ==================== 日历本操作 ====================

  // 获取所有日历本
  Future<List<CalendarBook>> getCalendarBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('calendars');

    return List.generate(maps.length, (i) {
      final map = maps[i];
      // 处理sharedWithUsers字段，将JSON字符串转换为List<String>
      final sharedWithUsersJson = map['sharedWithUsers'] as String? ?? '[]';
      final sharedWithUsers = List<String>.from(jsonDecode(sharedWithUsersJson) as List<dynamic>);

      return CalendarBook.fromMap({...map, 'sharedWithUsers': sharedWithUsers});
    });
  }

  // 插入日历本
  Future<int> insertCalendarBook(CalendarBook book) async {
    try {
      final db = await database;
      return await db.insert('calendars', book.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('插入日历本时出错: $e');
      // 打印插入的值，帮助调试
      print('尝试插入的数据: ${book.toMap()}');
      rethrow;
    }
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

  // 修改日程的完成状态
  Future<void> updateScheduleCompletionStatus(String scheduleId, bool isCompleted) async {
    final db = await database;
    await db.update('schedules', {'is_completed': isCompleted ? 1 : 0}, where: 'id = ?', whereArgs: [scheduleId]);
    debugPrint('DatabaseHelper: 日程完成状态更新成功，ID: $scheduleId, 完成状态: $isCompleted');
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

  // 重置数据库（删除并重新创建）
  Future<void> resetDatabase() async {
    try {
      debugPrint('开始重置数据库...');
      String path = join(await getDatabasesPath(), 'calendar_app.db');

      // 关闭现有数据库连接
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // 删除数据库文件
      await deleteDatabase(path);
      debugPrint('数据库文件已删除');

      // 重新初始化数据库
      _database = await _initDatabase();
      debugPrint('数据库已重新创建');
    } catch (e) {
      debugPrint('重置数据库时出错: $e');
      rethrow;
    }
  }
}
