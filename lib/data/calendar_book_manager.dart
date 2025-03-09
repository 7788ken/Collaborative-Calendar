import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/calendar_book.dart';
import 'database/database_helper.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule_item.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:async'; // 添加Timer支持
import '../services/api_auth_service.dart';
import 'package:sqflite/sqflite.dart'; // 添加 sqflite 导入
import '../data/schedule_service.dart'; // 添加这行导入

// 日历本管理类
class CalendarBookManager with ChangeNotifier {
  final _dbHelper = DatabaseHelper();
  final _apiService = ApiService();

  List<CalendarBook> _books = [];
  String _activeBookId = 'default';
  Map<String, String> _shareIdMap = {}; // 用于存储日历本ID到分享码的映射
  Map<String, DateTime?> _lastUpdateTimeMap = {}; // 用于存储日历本ID到最后更新时间的映射
  static const String _activeBookIdKey = 'active_calendar_book_id';

  // 定时器，用于定期检查日历更新
  Timer? _updateCheckTimer;
  // 定时器间隔（默认5分钟检查一次）
  static const Duration _updateCheckInterval = Duration(minutes: 5);
  // 是否启用定时同步（默认关闭）
  bool _enablePeriodicSync = false;

  // 检查服务器是否可用
  Future<bool> checkServerAvailability() async {
    try {
      debugPrint('检查服务器是否可用...');
      final result = await _apiService.checkServerStatus();
      debugPrint('服务器状态检查结果: $result');
      return result;
    } catch (e) {
      debugPrint('检查服务器状态时出错: $e');
      return false;
    }
  }

  List<CalendarBook> get books => _books;

  // 获取当前选中的日历本
  CalendarBook? get activeBook {
    try {
      return _books.firstWhere((book) => book.id == _activeBookId);
    } catch (e) {
      // 如果活动ID不存在，默认第一个
      return _books.isEmpty ? null : _books.first;
    }
  }

  // 获取日历本最后更新时间
  DateTime? getLastUpdateTime(String calendarId) {
    return _lastUpdateTimeMap[calendarId];
  }

  // 更新最后修改时间（如果日历是共享的）
  Future<void> _updateLastModifiedTimeIfShared(String calendarId) async {
    // 使用标志变量来跟踪进度
    bool calendarFound = false;
    bool isShared = false;
    bool hasShareCode = false;

    try {
      // 查找日历本
      CalendarBook? calendarBook;
      try {
        calendarBook = _books.firstWhere((book) => book.id == calendarId);
        calendarFound = true;
      } catch (e) {
        // 如果找不到日历本，则返回
        debugPrint('不更新最后修改时间: 找不到日历本 $calendarId');
        return;
      }

      // 如果日历本不是共享日历，则跳过
      if (!calendarBook.isShared) {
        debugPrint('不更新最后修改时间: 日历 $calendarId 不是共享日历');
        return;
      }
      isShared = true;

      // 获取分享码
      final shareCode = getShareId(calendarId);
      if (shareCode == null) {
        debugPrint('不更新最后修改时间: 无法获取日历 $calendarId 的分享码');
        return;
      }
      hasShareCode = true;

      // 获取当前缓存的最后更新时间
      final currentUpdateTime = _lastUpdateTimeMap[calendarId];
      debugPrint('本地最后更新时间: $currentUpdateTime');

      // 异步刷新最后修改时间，添加超时保护
      try {
        // 使用超时保护，防止长时间阻塞
        final serverUpdateTime = await _apiService
            .getCalendarLastUpdateTime(shareCode)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                debugPrint('获取日历 $calendarId 的最后修改时间超时');
                return null;
              },
            );

        debugPrint('服务器最后更新时间: $serverUpdateTime');

        // 如果服务器时间为空，则无法比较，直接返回
        if (serverUpdateTime == null) {
          debugPrint('未能获取日历 $calendarId 的有效最后修改时间');
          return;
        }

        // 检查是否有更新（时间不同或者之前没有记录时间）
        bool hasUpdate = currentUpdateTime == null || serverUpdateTime.isAfter(currentUpdateTime);

        if (hasUpdate) {
          debugPrint('检测到服务器有更新，最新时间: $serverUpdateTime，本地时间: $currentUpdateTime');
          // 更新本地缓存的时间为服务器时间
          _lastUpdateTimeMap[calendarId] = serverUpdateTime;

          // 保存最后同步时间到SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          final syncTimeKey = 'last_sync_time_$calendarId';
          await prefs.setInt(syncTimeKey, serverUpdateTime.millisecondsSinceEpoch);
          debugPrint('已保存服务器更新时间到SharedPreferences: $serverUpdateTime');

          // 触发自动拉取日程操作
          _autoFetchCalendarSchedules(calendarId, shareCode);
        } else {
          debugPrint('服务器没有更新，最新时间: $serverUpdateTime，本地时间: $currentUpdateTime');

          // 即使没有更新，也保存最后检查时间
          // 注意：这里我们保存的是本地时间，而不是服务器时间，因为服务器没有更新
          final prefs = await SharedPreferences.getInstance();
          final syncTimeKey = 'last_sync_time_$calendarId';
          await prefs.setInt(syncTimeKey, currentUpdateTime.millisecondsSinceEpoch);
          debugPrint('已保存最后检查时间到SharedPreferences: $currentUpdateTime');
        }

        // 通知监听器更新UI
        notifyListeners();
      } catch (e) {
        // 捕获并记录错误，但不将其传播
        debugPrint('获取日历 $calendarId 的最后修改时间出错: $e');
        // 我们不在这里重新抛出异常，以避免中断整个过程
      }
    } catch (e) {
      // 最外层错误处理
      debugPrint('更新日历最后修改时间的过程中发生未处理错误: $e');
      debugPrint('诊断信息: 日历找到=$calendarFound, 是共享日历=$isShared, 有分享码=$hasShareCode');
      // 不重新抛出异常
    }
  }

  // 自动拉取日历更新的日程数据
  Future<void> _autoFetchCalendarSchedules(String calendarId, String shareCode) async {
    try {
      debugPrint('开始自动拉取日历 $calendarId 的最新日程数据');

      // 异步执行拉取操作，不阻塞UI
      fetchSharedCalendarUpdates(calendarId)
          .then((_) {
            debugPrint('自动拉取日历 $calendarId 日程数据成功');
          })
          .catchError((error) {
            debugPrint('自动拉取日历 $calendarId 日程数据失败: $error');
            // 错误处理，但不影响主流程
          });
    } catch (e) {
      debugPrint('启动自动拉取日程操作时出错: $e');
      // 捕获错误但不重新抛出，确保不影响主流程
    }
  }

  // 检查日历的更新并根据需要拉取最新数据
  Future<bool> checkAndFetchCalendarUpdates(String calendarId) async {
    try {
      debugPrint('手动检查日历 $calendarId 的更新');

      // 确保是共享日历
      final calendarBook = _books.firstWhere((book) => book.id == calendarId && book.isShared, orElse: () => throw Exception('找不到共享日历本: $calendarId'));

      // 获取分享码
      final shareCode = getShareId(calendarId);
      if (shareCode == null) {
        debugPrint('无法找到日历 $calendarId 的分享码');
        return false;
      }

      // 获取当前缓存的最后更新时间
      final currentUpdateTime = _lastUpdateTimeMap[calendarId];
      debugPrint('本地最后更新时间: $currentUpdateTime');

      // 获取服务器最新的更新时间
      final serverUpdateTime = await _apiService.getCalendarLastUpdateTime(shareCode);
      debugPrint('服务器最后更新时间: $serverUpdateTime');

      // 如果服务器时间为空，则无法比较，返回false
      if (serverUpdateTime == null) {
        debugPrint('无法获取服务器更新时间，跳过更新');
        return false;
      }

      // 如果本地没有记录过时间，或者服务器时间比本地时间新，则拉取数据
      if (currentUpdateTime == null || serverUpdateTime.isAfter(currentUpdateTime)) {
        debugPrint('检测到服务器有更新，开始拉取数据');
        debugPrint('服务器时间: $serverUpdateTime, 本地时间: $currentUpdateTime');

        // 拉取最新数据
        await fetchSharedCalendarUpdates(calendarId);

        // 更新缓存的时间为服务器时间
        _lastUpdateTimeMap[calendarId] = serverUpdateTime;

        // 保存最后同步时间到SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final syncTimeKey = 'last_sync_time_$calendarId';
        await prefs.setInt(syncTimeKey, serverUpdateTime.millisecondsSinceEpoch);
        debugPrint('已保存服务器更新时间到SharedPreferences: $serverUpdateTime');

        notifyListeners();

        return true;
      } else {
        debugPrint('服务器没有更新，跳过拉取');
        debugPrint('服务器时间: $serverUpdateTime, 本地时间: $currentUpdateTime');

        // 即使没有更新，也更新最后检查时间
        // 注意：这里我们保存的是本地时间，而不是服务器时间，因为服务器没有更新
        final prefs = await SharedPreferences.getInstance();
        final syncTimeKey = 'last_sync_time_$calendarId';
        await prefs.setInt(syncTimeKey, currentUpdateTime.millisecondsSinceEpoch);
        debugPrint('已保存最后检查时间到SharedPreferences: $currentUpdateTime');

        return false;
      }
    } catch (e) {
      debugPrint('检查和拉取日历更新时出错: $e');
      return false;
    }
  }

  // 更新所有共享日历的最后修改时间
  Future<void> updateAllSharedCalendarsTimes() async {
    int successCount = 0;
    int failureCount = 0;
    List<String> failedCalendarIds = [];

    debugPrint('开始更新所有共享日历的最后修改时间');
    try {
      // 获取所有共享日历
      final sharedCalendars = _books.where((book) => book.isShared).toList();

      if (sharedCalendars.isEmpty) {
        debugPrint('没有找到共享日历，跳过更新时间');
        return;
      }

      debugPrint('发现 ${sharedCalendars.length} 个共享日历需要更新时间');

      // 准备用于保存任务完成状态的SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // 为每个共享日历更新最后修改时间
      for (final calendar in sharedCalendars) {
        try {
          final calendarId = calendar.id;

          // 获取分享码
          final shareCode = getShareId(calendarId);
          if (shareCode == null) {
            debugPrint('跳过日历 $calendarId: 无法获取分享码');
            failureCount++;
            failedCalendarIds.add(calendarId);
            continue;
          }

          // 获取当前缓存的最后更新时间
          final currentUpdateTime = _lastUpdateTimeMap[calendarId];
          debugPrint('本地最后更新时间: $currentUpdateTime');

          // 获取服务器最新的更新时间
          final serverUpdateTime = await _apiService
              .getCalendarLastUpdateTime(shareCode)
              .timeout(
                const Duration(seconds: 15),
                onTimeout: () {
                  debugPrint('获取日历 $calendarId 的最后修改时间超时');
                  return null;
                },
              );

          debugPrint('服务器最后更新时间: $serverUpdateTime');

          // 如果服务器时间为空，则无法比较，跳过此日历
          if (serverUpdateTime == null) {
            debugPrint('未能获取日历 $calendarId 的有效最后修改时间');
            failureCount++;
            failedCalendarIds.add(calendarId);
            continue;
          }

          // 检查是否有更新（时间不同或者之前没有记录时间）
          bool hasUpdate = currentUpdateTime == null || serverUpdateTime.isAfter(currentUpdateTime);

          // 更新缓存的时间
          if (hasUpdate) {
            // 如果服务器时间较新，则更新为服务器时间
            _lastUpdateTimeMap[calendarId] = serverUpdateTime;

            // 保存最后同步时间到SharedPreferences
            final syncTimeKey = 'last_sync_time_$calendarId';
            await prefs.setInt(syncTimeKey, serverUpdateTime.millisecondsSinceEpoch);
            debugPrint('已保存服务器更新时间到SharedPreferences: $serverUpdateTime');

            debugPrint('检测到服务器有更新，最新时间: $serverUpdateTime，本地时间: $currentUpdateTime');

            // 触发自动拉取日程操作
            _autoFetchCalendarSchedules(calendarId, shareCode);
          } else {
            debugPrint('服务器没有更新，最新时间: $serverUpdateTime，本地时间: $currentUpdateTime');

            // 即使没有更新，也保存最后检查时间
            // 注意：这里我们保存的是本地时间，而不是服务器时间，因为服务器没有更新
            final syncTimeKey = 'last_sync_time_$calendarId';
            await prefs.setInt(syncTimeKey, currentUpdateTime.millisecondsSinceEpoch);
            debugPrint('已保存最后检查时间到SharedPreferences: $currentUpdateTime');
          }

          successCount++;
        } catch (e) {
          failureCount++;
          failedCalendarIds.add(calendar.id);
          debugPrint('更新日历 ${calendar.id} 的最后修改时间失败: $e');
          // 继续处理下一个日历，不中断循环
          continue;
        }
      }

      // 通知监听器更新UI（仅做一次批量通知而不是每个日历单独通知）
      notifyListeners();

      debugPrint('共享日历最后修改时间更新完成。成功: $successCount, 失败: $failureCount');

      // 如果有失败的日历，记录它们的ID
      if (failureCount > 0) {
        debugPrint('以下日历更新失败: $failedCalendarIds');
      }
    } catch (e) {
      debugPrint('更新所有共享日历的最后修改时间过程中发生错误: $e');
      // 不重新抛出异常，以避免中断应用程序的启动
    }
  }

  // 设置当前选中的日历本
  Future<void> setActiveBook(String? id) async {
    // 如果id为null或者空字符串，直接返回
    if (id == null || id.isEmpty) {
      debugPrint('尝试设置无效的日历ID: $id');
      return;
    }

    if (_activeBookId != id && _books.any((book) => book.id == id)) {
      _activeBookId = id;

      // 保存选中状态到SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeBookIdKey, _activeBookId);

      notifyListeners();

      // 检查当前选中的日历本是否是共享日历
      final selectedBook = _books.firstWhere((book) => book.id == id);
      if (selectedBook.isShared) {
        debugPrint('切换到共享日历本，自动检查更新');

        // 直接更新当前日历的最后修改时间并同步
        try {
          await _updateLastModifiedTimeIfShared(id);
          debugPrint('成功更新共享日历 $id 的最后修改时间');
        } catch (e) {
          debugPrint('更新共享日历 $id 的最后修改时间时出错: $e');
        }
      }
    }
  }

  // 创建新日历本
  Future<void> createBook(String name, Color color) async {
    final newBook = CalendarBook(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, color: color);

    // 保存到数据库
    await _dbHelper.insertCalendarBook(newBook);

    // 更新内存中的列表
    _books.add(newBook);
    notifyListeners();
  }

  // 更新日历本名称
  Future<void> updateBookName(String id, String newName) async {
    final index = _books.indexWhere((book) => book.id == id);
    if (index != -1) {
      final updatedBook = _books[index].copyWith(name: newName);

      // 保存到数据库
      await _dbHelper.updateCalendarBook(updatedBook);

      // 更新内存中的列表
      _books[index] = updatedBook;
      notifyListeners();
    }
  }

  // 更新日历本颜色
  Future<void> updateBookColor(String id, Color newColor) async {
    final index = _books.indexWhere((book) => book.id == id);
    if (index != -1) {
      final updatedBook = _books[index].copyWith(color: newColor);

      // 保存到数据库
      await _dbHelper.updateCalendarBook(updatedBook);

      // 更新内存中的列表
      _books[index] = updatedBook;
      notifyListeners();
    }
  }

  // 同时更新日历本名称和颜色
  Future<void> updateBookNameAndColor(String id, String newName, Color newColor) async {
    final index = _books.indexWhere((book) => book.id == id);
    if (index != -1) {
      // 创建一个同时更新名称和颜色的新日历本对象
      final updatedBook = _books[index].copyWith(name: newName, color: newColor);

      // 保存到数据库
      await _dbHelper.updateCalendarBook(updatedBook);

      // 更新内存中的列表
      _books[index] = updatedBook;
      notifyListeners();
    }
  }

  // 删除日历本
  Future<void> deleteBook(String id) async {
    // 不允许删除最后一个日历本
    if (_books.length <= 1) return;

    final index = _books.indexWhere((book) => book.id == id);
    if (index != -1) {
      try {
        // 从数据库删除
        await _dbHelper.deleteCalendarBook(id);

        // 删除对应的分享码
        String? shareId = _shareIdMap[id];
        if (shareId != null) {
          debugPrint('删除日历本时移除分享码: $shareId');
          _shareIdMap.remove(id);

          // 从持久化存储中也删除
          final prefs = await SharedPreferences.getInstance();
          final shareIdsJson = prefs.getString('calendar_share_ids') ?? '{}';
          final shareIds = Map<String, String>.from(json.decode(shareIdsJson));
          shareIds.remove(id);
          await prefs.setString('calendar_share_ids', json.encode(shareIds));
        }

        // 如果删除的是当前选中的日历本，则自动选择另一个
        if (_activeBookId == id) {
          final newActiveId = _books.firstWhere((b) => b.id != id).id;
          setActiveBook(newActiveId);
        }

        // 更新内存中的列表
        _books.removeAt(index);
        notifyListeners();
      } catch (e) {
        debugPrint('删除日历本时出错: $e');
        rethrow;
      }
    }
  }

  // 导入共享日历本
  Future<bool> importSharedBook(String shareId, String name, Color color, String ownerId) async {
    // 检查是否已导入
    if (_books.any((book) => book.id == shareId)) {
      return false;
    }

    final sharedBook = CalendarBook(id: shareId, name: name, color: color, isShared: true, ownerId: ownerId);

    // 保存到数据库
    await _dbHelper.insertCalendarBook(sharedBook);

    // 更新内存中的列表
    _books.add(sharedBook);
    notifyListeners();

    return true;
  }

  // 更新日历本的共享状态
  Future<void> updateSharedStatus(String id, bool isShared) async {
    final index = _books.indexWhere((book) => book.id == id);
    if (index != -1) {
      final updatedBook = _books[index].copyWith(isShared: isShared);

      // 保存到数据库
      await _dbHelper.updateCalendarBook(updatedBook);

      // 更新内存中的列表
      _books[index] = updatedBook;
      notifyListeners();
    }
  }

  // 保存分享码到SharedPreferences
  Future<void> saveShareId(String calendarId, String shareCode) async {
    print('保存分享码：日历ID=$calendarId, 分享码=$shareCode');
    // 更新内存中的Map
    _shareIdMap[calendarId] = shareCode;

    try {
      // 保存到SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('share_ids', json.encode(_shareIdMap));
      print('成功保存分享码到SharedPreferences');
    } catch (e) {
      print('保存分享码到SharedPreferences失败: $e');
    }
  }

  // 从SharedPreferences加载分享码
  Future<void> _loadShareIds() async {
    try {
      print('开始从SharedPreferences加载分享码映射');
      final prefs = await SharedPreferences.getInstance();
      final shareIdsJson = prefs.getString('share_ids') ?? '{}';

      try {
        _shareIdMap = Map<String, String>.from(json.decode(shareIdsJson));
        print('成功加载分享码映射: $_shareIdMap');
      } catch (e) {
        print('解析分享码JSON失败: $e，将使用空映射');
        _shareIdMap = {};
      }

      // 验证所有日历本是否都有对应的分享码
      for (var book in _books.where((b) => b.isShared)) {
        if (!_shareIdMap.containsKey(book.id)) {
          print('警告: 共享日历 ${book.name}(${book.id}) 没有对应的分享码');
        } else {
          print('共享日历 ${book.name}(${book.id}) 的分享码: ${_shareIdMap[book.id]}');
        }
      }

      // 清理无效的分享码（对应的日历本已不存在）
      final bookIds = _books.map((b) => b.id).toSet();
      final keysToRemove = _shareIdMap.keys.where((key) => !bookIds.contains(key)).toList();

      if (keysToRemove.isNotEmpty) {
        print('清理无效的分享码映射: $keysToRemove');
        for (var key in keysToRemove) {
          _shareIdMap.remove(key);
        }

        // 保存清理后的映射
        await prefs.setString('share_ids', json.encode(_shareIdMap));
        print('已保存清理后的分享码映射');
      }
    } catch (e) {
      print('加载分享码映射时出错: $e');
    }
  }

  // 获取指定日历本的分享码
  String? getShareId(String calendarId) {
    final shareCode = _shareIdMap[calendarId];
    print('获取日历ID=$calendarId 的分享码: $shareCode');
    return shareCode;
  }

  // 复制日历本及其所有日程到一个新的本地日历本
  Future<String> copyCalendarBook(String sourceCalendarId, String newName, Color newColor) async {
    try {
      print('开始复制日历本: $sourceCalendarId');

      // 获取源日历本
      final sourceBook = _books.firstWhere((book) => book.id == sourceCalendarId, orElse: () => throw Exception('找不到源日历本: $sourceCalendarId'));

      // 创建新的日历本
      final newId = const Uuid().v4();
      final newBook = CalendarBook(
        id: newId,
        name: newName,
        color: newColor,
        isShared: false, // 新复制的日历本始终是本地日历
        ownerId: null,
        sharedWithUsers: [],
        createdAt: DateTime.now(),
      );

      // 保存新日历本
      await _dbHelper.insertCalendarBook(newBook);

      // 获取源日历本的所有日程
      final schedules = await _dbHelper.getSchedules(sourceCalendarId);

      // 复制日程到新的日历本
      int count = 0;
      for (var schedule in schedules) {
        final newSchedule = ScheduleItem(
          id: const Uuid().v4(), // 为新日程生成新的唯一ID
          calendarId: newId,
          title: schedule.title,
          description: schedule.description,
          startTime: schedule.startTime,
          endTime: schedule.endTime,
          isAllDay: schedule.isAllDay,
          location: schedule.location,
        );

        await _dbHelper.insertSchedule(newSchedule);
        count++;
      }

      // 将新日历本添加到内存列表
      _books.add(newBook);

      print('成功复制日历本，ID: $newId, 复制了 $count 个日程');

      // 通知监听器
      notifyListeners();

      return newId;
    } catch (e) {
      print('复制日历本时出错: $e');
      rethrow;
    }
  }

  // 分享日历到云端
  Future<String> shareCalendarToCloud(String calendarId) async {
    try {
      // 获取日历本信息
      final calendarBook = _books.firstWhere((book) => book.id == calendarId, orElse: () => throw Exception('找不到日历本: $calendarId'));

      // 获取该日历本下的所有日程
      final schedules = await _dbHelper.getSchedules(calendarId);

      // 调用API上传日历和日程
      final shareCode = await _apiService.shareCalendar(calendarBook, schedules);

      // 更新日历本为共享状态
      await updateSharedStatus(calendarId, true);

      // 保存分享码
      await saveShareId(calendarId, shareCode);

      return shareCode;
    } catch (e) {
      debugPrint('分享日历到云端失败: $e');
      rethrow;
    }
  }

  // 从云端导入共享日历
  Future<bool> importSharedCalendarFromCloud(String shareCode) async {
    try {
      debugPrint('开始从云端导入日历，分享码: $shareCode');

      // 检查分享码是否有效
      if (shareCode.isEmpty) {
        debugPrint('分享码为空，无法导入日历');
        return false;
      }

      // 检查是否已导入 - 改进检查逻辑
      bool isAlreadyImported = false;
      String? existingCalendarId;

      // 先从持久化存储获取完整的分享码映射
      final prefs = await SharedPreferences.getInstance();
      final shareIdsJson = prefs.getString('share_ids') ?? '{}';
      final shareIds = Map<String, String>.from(json.decode(shareIdsJson));

      // 查找是否有日历使用了这个分享码
      shareIds.forEach((calendarId, storedShareCode) {
        if (storedShareCode == shareCode) {
          existingCalendarId = calendarId;
        }
      });

      // 如果找到了分享码，还需要检查对应的日历是否真的存在
      if (existingCalendarId != null) {
        isAlreadyImported = _books.any((book) => book.id == existingCalendarId);

        // 如果分享码存在但日历不存在，清理这个过时的映射
        if (!isAlreadyImported) {
          debugPrint('发现孤立的分享码映射，正在清理: $existingCalendarId -> $shareCode');
          _shareIdMap.remove(existingCalendarId);
          shareIds.remove(existingCalendarId);
          await prefs.setString('share_ids', json.encode(shareIds));
        }
      }

      if (isAlreadyImported && existingCalendarId != null) {
        debugPrint('日历已导入，分享码: $shareCode, 日历ID: $existingCalendarId');
        // 自动切换到已导入的日历
        await setActiveBook(existingCalendarId);
        debugPrint('已自动切换到已导入的日历');
        return false;
      } else if (isAlreadyImported) {
        debugPrint('日历已导入，但无法确定日历ID');
        return false;
      }

      // 从API获取日历信息
      debugPrint('正在从服务器获取日历信息...');
      final Map<String, dynamic> calendarData;
      try {
        calendarData = await _apiService.getSharedCalendar(shareCode);
        debugPrint('获取到日历信息: $calendarData');
      } catch (e) {
        debugPrint('获取日历信息失败: $e');
        // 尝试通过不同的错误消息提供更具体的反馈
        if (e.toString().contains('不包含calendar字段')) {
          debugPrint('服务器返回的数据格式不正确。请检查分享码是否有效或服务器是否工作正常。');
        } else if (e.toString().contains('连接超时') || e.toString().contains('SocketException')) {
          debugPrint('网络连接错误。请检查网络连接并重试。');
        }
        return false;
      }

      // 验证必要的字段是否存在
      if (!calendarData.containsKey('name') || !calendarData.containsKey('color')) {
        debugPrint('日历数据缺少必要的字段: 名称或颜色');
        return false;
      }

      // 创建日历本对象
      String colorHex = calendarData['color'] as String;
      // 去掉可能的#前缀
      if (colorHex.startsWith('#')) {
        colorHex = colorHex.substring(1);
      }

      // 处理可能的格式问题
      int colorValue;
      try {
        colorValue = int.parse(colorHex, radix: 16);
        // 如果解析的颜色没有alpha值，添加完全不透明的alpha通道
        if (colorHex.length <= 6) {
          colorValue = colorValue | 0xFF000000;
        }
      } catch (e) {
        debugPrint('解析颜色时出错: $e，使用默认蓝色');
        colorValue = Colors.blue.value;
      }

      final calendarId = const Uuid().v4();
      final calendarBook = CalendarBook(id: calendarId, name: calendarData['name'], color: Color(colorValue), isShared: true, ownerId: calendarData['ownerId']);

      debugPrint('创建日历本对象: ${calendarBook.name}');

      // 保存日历本到数据库
      await _dbHelper.insertCalendarBook(calendarBook);

      // 保存分享码
      await saveShareId(calendarId, shareCode);

      debugPrint('开始获取日程数据');

      // 从API获取该日历下的所有日程
      try {
        final schedulesData = await _apiService.getSchedules(shareCode);
        debugPrint('获取到日程数据: $schedulesData');

        if (schedulesData != null && schedulesData.isNotEmpty) {
          // 保存日程到数据库
          for (var scheduleData in schedulesData) {
            try {
              debugPrint('处理日程: $scheduleData');

              // 确保日期字段是整数时间戳
              final startTime = scheduleData['startTime'];
              final endTime = scheduleData['endTime'];

              if (startTime == null || endTime == null) {
                debugPrint('警告: 日程缺少开始或结束时间，跳过');
                continue;
              }

              final startDateTime = startTime is int ? DateTime.fromMillisecondsSinceEpoch(startTime) : DateTime.parse(startTime.toString());

              final endDateTime = endTime is int ? DateTime.fromMillisecondsSinceEpoch(endTime) : DateTime.parse(endTime.toString());

              // 获取任务完成状态
              final isCompleted = scheduleData['isCompleted'] == true;

              final schedule = ScheduleItem(
                id: scheduleData['id'] ?? const Uuid().v4(),
                calendarId: calendarId,
                title: scheduleData['title'],
                description: scheduleData['description'],
                startTime: startDateTime,
                endTime: endDateTime,
                isAllDay: scheduleData['isAllDay'] == 1,
                location: scheduleData['location'],
                isCompleted: isCompleted, // 设置完成状态
              );

              await _dbHelper.insertSchedule(schedule);
              debugPrint('成功保存日程: ${schedule.title}, 完成状态: $isCompleted');

              // 如果任务已完成，同时保存完成状态到SharedPreferences
              if (isCompleted) {
                final taskKey = '${startDateTime.year}-${startDateTime.month}-${startDateTime.day}-${schedule.id}';
                await prefs.setBool('task_$taskKey', true);
                debugPrint('已保存任务完成状态到本地: $taskKey = true');
              }
            } catch (e) {
              debugPrint('保存单个日程时出错: $e');
              // 继续处理其他日程，不中断整个过程
            }
          }
        } else {
          debugPrint('没有找到日程数据或数据为空');
        }

        // 将新日历本添加到内存列表
        _books.add(calendarBook);
        notifyListeners();

        debugPrint('成功导入日历: ${calendarBook.name}');

        // 成功导入后，自动切换到这个日历本
        await setActiveBook(calendarId);

        // 确保立即获取最后更新时间
        await _updateLastModifiedTimeIfShared(calendarId);

        return true;
      } catch (e) {
        debugPrint('获取日程数据时出错: $e');
        return false;
      }
    } catch (e) {
      debugPrint('从云端导入日历失败: $e');
      return false;
    }
  }

  // 同步共享日历日程到云端
  Future<bool> syncSharedCalendarSchedules(String calendarId, {String? specificScheduleId}) async {
    debugPrint('CalendarBookManager: 开始同步共享日历日程');

    try {
      // 防御性校验参数
      if (calendarId.isEmpty) {
        debugPrint('CalendarBookManager: 错误 - 日历ID为空');
        return false;
      }

      // 检查日历是否存在
      bool calendarExists = false;
      try {
        calendarExists = _books.any((book) => book.id == calendarId);
        if (!calendarExists) {
          debugPrint('CalendarBookManager: 错误 - 找不到ID为 $calendarId 的日历');
          return false;
        }
      } catch (e) {
        debugPrint('CalendarBookManager: 检查日历是否存在时出错: $e');
        return false;
      }

      // 获取分享码
      String? shareCode;
      try {
        shareCode = getShareId(calendarId);
        if (shareCode == null) {
          debugPrint('CalendarBookManager: 错误 - 未找到日历本的分享码');
          return false;
        }
        debugPrint('CalendarBookManager: 获取到分享码: $shareCode');
      } catch (e) {
        debugPrint('CalendarBookManager: 获取分享码时出错: $e');
        return false;
      }

      // 如果指定了特定日程ID，则只同步该日程
      if (specificScheduleId != null) {
        debugPrint('CalendarBookManager: 仅同步特定日程 ID: $specificScheduleId');
        try {
          return await _syncSpecificTask(calendarId, shareCode, specificScheduleId);
        } catch (e) {
          debugPrint('CalendarBookManager: 同步特定日程时出错: $e');
          return false;
        }
      }

      // 否则，获取所有需要同步的日程
      List<ScheduleItem> schedules = [];
      try {
        debugPrint('CalendarBookManager: 获取所有需要同步的日程');
        schedules = await _getSchedulesNeedSync(calendarId);

        if (schedules.isEmpty) {
          debugPrint('CalendarBookManager: 没有需要同步的日程');
          return true; // 没有需要同步的内容也算成功
        }

        debugPrint('CalendarBookManager: 找到 ${schedules.length} 条需要同步的日程');
      } catch (e) {
        debugPrint('CalendarBookManager: 获取需要同步的日程时出错: $e');
        return false;
      }

      // 创建一个列表存储所有日程的同步数据
      List<Map<String, dynamic>> syncData = [];

      try {
        // 处理每条日程数据
        for (var schedule in schedules) {
          try {
            final scheduleData = {
              'id': schedule.id,
              'title': schedule.title,
              'description': schedule.description,
              'location': schedule.location,
              'startTime': schedule.startTime.millisecondsSinceEpoch,
              'endTime': schedule.endTime.millisecondsSinceEpoch,
              'isAllDay': schedule.isAllDay ? 1 : 0,
              'isCompleted': schedule.isCompleted ? 1 : 0,
              'is_deleted': 0, // 默认未删除
            };

            debugPrint('CalendarBookManager: 准备同步的日程数据: ${schedule.title}');
            syncData.add(scheduleData);
          } catch (e) {
            debugPrint('CalendarBookManager: 处理单个日程数据时出错: $e');
            // 继续处理其他日程，不中断整个过程
          }
        }

        if (syncData.isEmpty) {
          debugPrint('CalendarBookManager: 所有日程处理都失败，没有可同步的数据');
          return false;
        }

        debugPrint('CalendarBookManager: 成功准备 ${syncData.length} 条日程数据用于同步');
      } catch (e) {
        debugPrint('CalendarBookManager: 准备同步数据时出错: $e');
        return false;
      }

      // 使用API进行批量同步
      try {
        debugPrint('CalendarBookManager: 发送批量同步请求，日程数量: ${syncData.length}');

        // 添加超时保护
        final result = await _apiService
            .syncSchedules(shareCode, syncData)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                debugPrint('CalendarBookManager: 同步请求超时');
                return <String, dynamic>{'success': false, 'message': '同步请求超时'};
              },
            );

        if (result['success'] == true) {
          debugPrint('CalendarBookManager: 同步成功，服务器响应: $result');

          // 更新已同步的日程状态
          await _updateSyncStatus(calendarId, schedules);
          return true;
        } else {
          debugPrint('CalendarBookManager: 同步失败，服务器返回: $result');
          return false;
        }
      } catch (e) {
        debugPrint('CalendarBookManager: 同步请求失败: $e');
        return false;
      }
    } catch (e) {
      debugPrint('CalendarBookManager: 同步共享日历日程过程中发生未预期错误: $e');
      return false;
    }
  }

  // 同步单个特定日程
  Future<bool> _syncSpecificTask(String calendarId, String shareCode, String scheduleId) async {
    try {
      debugPrint('CalendarBookManager: 开始同步特定日程 ID: $scheduleId');

      // 获取日程数据
      final schedules = await _dbHelper.getScheduleById(scheduleId);
      if (schedules.isEmpty) {
        debugPrint('CalendarBookManager: 本地未找到日程，可能已被删除');
        debugPrint('CalendarBookManager: 跳过同步，因为删除操作应该已经通过专门的API完成');
        return false;
      }

      final schedule = schedules.first;

      // 准备同步数据
      final scheduleData = {'id': schedule.id, 'title': schedule.title, 'description': schedule.description, 'location': schedule.location, 'startTime': schedule.startTime.millisecondsSinceEpoch, 'endTime': schedule.endTime.millisecondsSinceEpoch, 'isAllDay': schedule.isAllDay ? 1 : 0, 'isCompleted': schedule.isCompleted ? 1 : 0};

      debugPrint('CalendarBookManager: 准备同步的日程数据: ${schedule.title}');

      // 使用API进行同步
      final result = await _apiService.syncSchedules(shareCode, [scheduleData]);

      if (result['success'] == true) {
        debugPrint('CalendarBookManager: 特定日程同步成功');

        // 更新已同步状态
        await _dbHelper.updateScheduleSyncStatus(schedule.id, true);
        return true;
      } else {
        debugPrint('CalendarBookManager: 特定日程同步失败: ${result['message']}');
        return false;
      }
    } catch (e) {
      debugPrint('CalendarBookManager: 同步特定日程错误: $e');
      return false;
    }
  }

  // 获取需要同步的日程
  Future<List<ScheduleItem>> _getSchedulesNeedSync(String calendarId) async {
    try {
      debugPrint('CalendarBookManager: 开始获取需要同步的日程，日历ID: $calendarId');

      // 参数校验
      if (calendarId.isEmpty) {
        debugPrint('CalendarBookManager: 错误 - 日历ID为空');
        return [];
      }

      try {
        // 获取最近修改的日程
        final schedules = await _dbHelper.getRecentlyModifiedSchedules(calendarId);
        debugPrint('CalendarBookManager: 获取到 ${schedules.length} 条需要同步的日程');
        return schedules;
      } catch (e) {
        debugPrint('CalendarBookManager: 查询数据库获取最近修改的日程时出错: $e');
        return [];
      }
    } catch (e) {
      debugPrint('CalendarBookManager: 获取需要同步的日程时发生未预期错误: $e');
      return [];
    }
  }

  // 更新日程的同步状态
  Future<void> _updateSyncStatus(String calendarId, List<ScheduleItem> schedules) async {
    try {
      debugPrint('CalendarBookManager: 开始更新日程同步状态，日历ID: $calendarId，日程数量: ${schedules.length}');

      // 参数校验
      if (calendarId.isEmpty) {
        debugPrint('CalendarBookManager: 错误 - 日历ID为空');
        return;
      }

      if (schedules.isEmpty) {
        debugPrint('CalendarBookManager: 没有需要更新同步状态的日程');
        return;
      }

      int successCount = 0;
      List<String> failedIds = [];

      // 逐个更新日程的同步状态
      for (var schedule in schedules) {
        try {
          await _dbHelper.updateScheduleSyncStatus(schedule.id, true);
          successCount++;
        } catch (e) {
          debugPrint('CalendarBookManager: 更新日程 ${schedule.id} 同步状态时出错: $e');
          failedIds.add(schedule.id);
          // 继续处理其他日程，不中断整个过程
        }
      }

      debugPrint('CalendarBookManager: 更新同步状态完成。成功: $successCount, 失败: ${failedIds.length}');

      if (failedIds.isNotEmpty) {
        debugPrint('CalendarBookManager: 以下日程同步状态更新失败: $failedIds');
      }
    } catch (e) {
      debugPrint('CalendarBookManager: 更新同步状态过程中发生未预期错误: $e');
      // 捕获异常，避免中断调用者的执行流程
    }
  }

  // 获取任务完成状态数据
  Future<Map<String, bool>> _getScheduleData() async {
    try {
      // 从SharedPreferences获取任务完成状态
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      // 创建状态Map
      final Map<String, bool> taskStatus = {};

      for (final key in allKeys) {
        if (key.startsWith('task_')) {
          final taskKey = key.substring(5); // 去掉前缀'task_'
          taskStatus[taskKey] = prefs.getBool(key) ?? false;
        }
      }

      debugPrint('已加载 ${taskStatus.length} 个任务状态用于同步');
      return taskStatus;
    } catch (e) {
      debugPrint('加载任务状态时出错: $e');
      return {}; // 返回空Map避免同步失败
    }
  }

  // 从云端下载最新的日程数据
  Future<bool> fetchSharedCalendarUpdates(String calendarId) async {
    try {
      debugPrint('开始获取共享日历更新，日历ID: $calendarId');

      // 获取分享码
      final shareCode = getShareId(calendarId);
      if (shareCode == null) {
        debugPrint('未找到分享码，无法获取更新');
        return false;
      }

      // 获取服务器上的日程数据
      final List<dynamic> schedulesData = await _apiService.getSchedules(shareCode);
      debugPrint('从服务器获取到 ${schedulesData.length} 条日程数据');

      // 获取本地未同步的日程
      final unsyncedSchedules = await _dbHelper.getUnsyncedSchedules(calendarId);
      debugPrint('本地有 ${unsyncedSchedules.length} 条未同步的日程');

      // 创建一个映射来存储未同步日程的ID
      final unsyncedIds = Set<String>.from(unsyncedSchedules.map((s) => s.id));

      // 开始数据库事务
      final db = await _dbHelper.database;

      // 使用批处理来提高性能
      final batch = db.batch();

      try {
        // 1. 删除已同步的日程（保留未同步的）
        batch.delete('schedules', where: 'calendar_id = ? AND (sync_status = 1 OR sync_status IS NULL)', whereArgs: [calendarId]);

        // 2. 准备新日程数据的批量插入
        for (final scheduleData in schedulesData) {
          try {
            final String scheduleId = scheduleData['id'] as String;

            // 跳过未同步的日程
            if (unsyncedIds.contains(scheduleId)) {
              debugPrint('跳过未同步的日程: $scheduleId');
              continue;
            }

            // 转换日期格式
            final startTime = scheduleData['startTime'];
            final endTime = scheduleData['endTime'];

            final Map<String, dynamic> dbScheduleData = {
              'id': scheduleId,
              'calendar_id': calendarId,
              'title': scheduleData['title'],
              'description': scheduleData['description'],
              'start_time': startTime is int ? startTime : DateTime.parse(startTime.toString()).millisecondsSinceEpoch,
              'end_time': endTime is int ? endTime : DateTime.parse(endTime.toString()).millisecondsSinceEpoch,
              'is_all_day': scheduleData['isAllDay'] == true || scheduleData['isAllDay'] == 1 ? 1 : 0,
              'location': scheduleData['location'],
              'created_at': DateTime.now().millisecondsSinceEpoch,
              'is_completed': scheduleData['isCompleted'] == true || scheduleData['isCompleted'] == 1 ? 1 : 0,
              'sync_status': 1,
            };

            batch.insert('schedules', dbScheduleData, conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            debugPrint('处理单个日程时出错: $e');
            continue;
          }
        }

        // 3. 执行批处理操作
        await batch.commit(noResult: true, continueOnError: true);
        debugPrint('批量更新数据库完成');

        // 通知监听器数据已更新
        notifyListeners();

        debugPrint('日历更新完成');
        return true;
      } catch (e) {
        debugPrint('批处理执行过程中出错: $e');
        // 出错时尝试回滚批处理
        await batch.commit(noResult: true);
        return false;
      }
    } catch (e) {
      debugPrint('获取共享日历更新时出错: $e');
      return false;
    }
  }

  // 获取指定日历的所有任务完成状态
  Future<Map<String, bool>> _getTaskStatusForCalendar(String calendarId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final Map<String, bool> result = {};

      // 获取此日历下所有日程
      final schedules = await _dbHelper.getSchedules(calendarId);

      // 遍历所有日程，检查其完成状态
      for (final schedule in schedules) {
        // 检查新格式的任务完成状态键
        final newKey = 'task_completed_${schedule.id}';
        if (prefs.containsKey(newKey)) {
          result[schedule.id] = prefs.getBool(newKey) ?? false;
          continue;
        }

        // 检查旧格式的任务完成状态键
        final oldKey = 'task_${schedule.startTime.year}-${schedule.startTime.month}-${schedule.startTime.day}-${schedule.id}';
        if (prefs.containsKey(oldKey)) {
          result[schedule.id] = prefs.getBool(oldKey) ?? false;

          // 迁移到新格式
          await prefs.setBool(newKey, result[schedule.id]!);
          await prefs.remove(oldKey);
          debugPrint('已将任务完成状态从旧格式迁移到新格式: $oldKey -> $newKey');
        }
      }

      debugPrint('获取到日历 $calendarId 的任务完成状态: ${result.length} 条记录');
      return result;
    } catch (e) {
      debugPrint('获取任务完成状态时出错: $e');
      return {}; // 返回空Map，避免操作失败
    }
  }

  // 添加测试方法：直接同步特定任务ID的完成状态
  Future<bool> syncSpecificTask(String shareCode, String scheduleId, bool newStatus) async {
    try {
      final apiService = ApiService();
      final scheduleService = ScheduleService();

      // 获取日程信息
      final schedules = await scheduleService.getScheduleById(scheduleId);
      if (schedules.isEmpty) {
        debugPrint('CalendarBookManager: 找不到指定的日程');
        return false;
      }

      final result = await apiService.updateScheduleStatus(
        shareCode,
        scheduleId,
        newStatus,
        schedules.first, // 使用第一个匹配的日程
        null, // 这里传 null 因为这是后台同步，不需要显示 UI 提示
      );

      return result['success'] == true;
    } catch (e) {
      debugPrint('CalendarBookManager: 同步特定任务时出错: $e');
      return false;
    }
  }

  // 初始化方法
  Future<void> init() async {
    try {
      debugPrint('开始初始化日历本管理器');

      // 从数据库加载日历本列表
      try {
        _books = await _dbHelper.getCalendarBooks();
        debugPrint('已加载 ${_books.length} 本日历');
      } catch (e) {
        debugPrint('加载日历本列表失败: $e');
        // 使用默认值
        _books = [];
      }

      // 如果没有日历本（首次运行），创建默认日历本
      if (_books.isEmpty) {
        debugPrint('没有找到日历本，创建默认日历');
        final defaultBook = CalendarBook(id: 'default', name: '我的日历', color: Colors.blue);

        try {
          await _dbHelper.insertCalendarBook(defaultBook);
          _books = [defaultBook];
          debugPrint('已创建默认日历本');
        } catch (e) {
          debugPrint('创建默认日历本失败: $e');
          // 即使数据库操作失败，也在内存中保留默认日历本
          _books = [defaultBook];
        }
      }

      // 从SharedPreferences加载上次选中的日历本ID
      String activeId = 'default';
      try {
        final prefs = await SharedPreferences.getInstance();
        activeId = prefs.getString(_activeBookIdKey) ?? 'default';
        debugPrint('从SharedPreferences加载活动日历ID: $activeId');
      } catch (e) {
        debugPrint('加载活动日历ID失败: $e');
        // 使用默认值
      }

      // 确保选中的日历本在列表中存在，否则默认选中第一个
      _activeBookId = activeId;
      if (!_books.any((book) => book.id == _activeBookId)) {
        _activeBookId = _books.first.id;
        debugPrint('选中的日历本不存在，默认选择第一个: $_activeBookId');

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_activeBookIdKey, _activeBookId);
        } catch (e) {
          debugPrint('保存默认活动日历ID失败: $e');
        }
      }

      // 加载分享码
      try {
        await _loadShareIds();
        debugPrint('已加载分享码映射');
      } catch (e) {
        debugPrint('加载分享码映射失败: $e');
      }

      // 从SharedPreferences加载所有日历的最后同步时间
      try {
        final prefs = await SharedPreferences.getInstance();

        // 遍历所有日历本
        for (final book in _books) {
          if (book.isShared) {
            final syncTimeKey = 'last_sync_time_${book.id}';
            if (prefs.containsKey(syncTimeKey)) {
              final timestamp = prefs.getInt(syncTimeKey);
              if (timestamp != null) {
                final syncTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
                _lastUpdateTimeMap[book.id] = syncTime;
                debugPrint('已加载日历 ${book.id} 的最后同步时间: $syncTime');
              }
            }
          }
        }

        debugPrint('已加载所有日历的最后同步时间');
      } catch (e) {
        debugPrint('加载日历同步时间失败: $e');
      }

      // 加载完成后，更新所有共享日历的最后修改时间
      // 使用防御性编程，确保即使更新失败也不会中断初始化
      try {
        // 只同步当前选中的日历
        if (activeBook != null && activeBook!.isShared) {
          debugPrint('仅同步当前选中的共享日历: ${activeBook!.id}');
          await _updateLastModifiedTimeIfShared(activeBook!.id);
        } else {
          debugPrint('当前选中的日历不是共享日历或未找到，跳过同步');
        }
      } catch (e) {
        debugPrint('更新当前共享日历时间失败，但继续初始化: $e');
      }

      // 只有在启用定时同步时才启动定时器
      if (_enablePeriodicSync) {
        _startUpdateCheckTimer();
      } else {
        debugPrint('定时同步功能已关闭，不启动定时器');
      }

      // 通知监听器完成初始化
      try {
        notifyListeners();
      } catch (e) {
        debugPrint('通知监听器时出错: $e');
      }

      debugPrint('日历本管理器初始化完成');
    } catch (e) {
      debugPrint('初始化日历本管理器失败: $e');
      // 错误处理，使用内存中的默认值
      _books = [CalendarBook(id: 'default', name: '我的日历', color: Colors.blue)];
      _activeBookId = 'default';
    }
  }

  @override
  void dispose() {
    // 取消定时器
    _updateCheckTimer?.cancel();
    super.dispose();
  }

  // 启动定时器，定期检查日历更新
  void _startUpdateCheckTimer() {
    // 如果定时同步被禁用，则直接返回
    if (!_enablePeriodicSync) {
      debugPrint('定时同步功能已关闭，不启动定时器');
      return;
    }

    // 确保先取消之前的定时器
    _updateCheckTimer?.cancel();

    debugPrint('启动日历更新检查定时器，间隔: $_updateCheckInterval');

    // 创建新的定时器
    _updateCheckTimer = Timer.periodic(_updateCheckInterval, (timer) {
      debugPrint('定时器触发：开始检查所有共享日历更新');
      updateAllSharedCalendarsTimes().catchError((error) {
        debugPrint('定时检查日历更新时出错: $error');
      });
    });
  }

  // 从API数据创建日程对象
  Future<ScheduleItem> _createScheduleFromApiData(Map<String, dynamic> scheduleData, String calendarId) async {
    // 确保日期字段是整数时间戳
    final startTime = scheduleData['startTime'];
    final endTime = scheduleData['endTime'];
    final scheduleId = scheduleData['id'];

    if (startTime == null || endTime == null || scheduleId == null) {
      throw Exception('日程数据不完整: $scheduleData');
    }

    final startDateTime = startTime is int ? DateTime.fromMillisecondsSinceEpoch(startTime) : DateTime.parse(startTime.toString());

    final endDateTime = endTime is int ? DateTime.fromMillisecondsSinceEpoch(endTime) : DateTime.parse(endTime.toString());

    // 获取服务器返回的完成状态
    final isCompleted = scheduleData['isCompleted'] == 1 || scheduleData['isCompleted'] == true;

    return ScheduleItem(id: scheduleId, calendarId: calendarId, title: scheduleData['title'], description: scheduleData['description'], startTime: startDateTime, endTime: endDateTime, isAllDay: scheduleData['isAllDay'] == 1 || scheduleData['isAllDay'] == true, location: scheduleData['location'], isCompleted: isCompleted);
  }
}
