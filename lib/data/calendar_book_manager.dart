import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/calendar_book.dart';
import 'database/database_helper.dart';
import '../models/schedule_item.dart';
import '../services/api_service.dart';
import 'dart:async'; // 添加Timer支持

// 日历本管理类
class CalendarBookManager with ChangeNotifier {
  final _dbHelper = DatabaseHelper();
  final _apiService = ApiService();

  List<CalendarBook> _books = [];
  String _activeBookId = 'default';
  Map<String, String> _shareIdMap = {}; // 用于存储日历本ID到分享码的映射
  Map<String, DateTime?> _lastUpdateTimeMap = {}; // 用于存储日历本ID到最后更新时间的映射
  static const String _activeBookIdKey = 'active_calendar_book_id';

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
    // 首先尝试从缓存中获取更新时间
    final cachedTime = _lastUpdateTimeMap[calendarId];
    if (cachedTime != null) {
      return cachedTime;
    }

    // 如果缓存中没有，尝试从日历本对象中获取
    try {
      final book = _books.firstWhere((book) => book.id == calendarId);
      return book.updatedAt;
    } catch (e) {
      // 如果找不到日历本，返回null
      return null;
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
    }
  }

  // 页面事件-创建新日历本
  Future<void> Page_function_createBook(String name, Color color) async {
    debugPrint('页面事件-创建新日历本: $name, $color');
    final newBook = CalendarBook.create(name: name, color: color);

    // 保存到数据库
    await _dbHelper.insertCalendarBook(newBook);

    // 更新内存中的列表
    _books.add(newBook);
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

      // 更新最后更新时间映射
      _lastUpdateTimeMap[id] = updatedBook.updatedAt;

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

      // 更新最后更新时间映射
      _lastUpdateTimeMap[id] = updatedBook.updatedAt;

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

      // 更新最后更新时间映射
      _lastUpdateTimeMap[id] = updatedBook.updatedAt;

      notifyListeners();
    }
  }

  // 更新日历本的分享码
  Future<void> updateBookShareCode(String id, String? shareCode) async {
    final index = _books.indexWhere((book) => book.id == id);
    if (index != -1) {
      // 创建一个更新分享码的新日历本对象
      final updatedBook = _books[index].copyWithShareCode(shareCode);

      // 保存到数据库
      await _dbHelper.updateCalendarBook(updatedBook);

      // 更新内存中的列表
      _books[index] = updatedBook;

      // 更新最后更新时间映射
      _lastUpdateTimeMap[id] = updatedBook.updatedAt;

      // 更新分享码映射
      if (shareCode != null) {
        _shareIdMap[id] = shareCode;

        // 保存分享码映射到SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          final shareIdsJson = prefs.getString('calendar_share_ids') ?? '{}';
          final shareIds = Map<String, String>.from(json.decode(shareIdsJson));
          shareIds[id] = shareCode;
          await prefs.setString('calendar_share_ids', json.encode(shareIds));
          debugPrint('已保存日历 $id 的分享码: $shareCode');
        } catch (e) {
          debugPrint('保存分享码映射失败: $e');
        }
      } else {
        // 如果分享码为null，则从映射中移除
        _shareIdMap.remove(id);

        // 从SharedPreferences中移除
        try {
          final prefs = await SharedPreferences.getInstance();
          final shareIdsJson = prefs.getString('calendar_share_ids') ?? '{}';
          final shareIds = Map<String, String>.from(json.decode(shareIdsJson));
          shareIds.remove(id);
          await prefs.setString('calendar_share_ids', json.encode(shareIds));
          debugPrint('已移除日历 $id 的分享码');
        } catch (e) {
          debugPrint('移除分享码映射失败: $e');
        }
      }

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

      // 加载所有日历本的更新时间
      await _loadCalendarUpdateTimes();

      // 加载分享码映射
      try {
        final prefs = await SharedPreferences.getInstance();
        final shareIdsJson = prefs.getString('calendar_share_ids') ?? '{}';
        _shareIdMap = Map<String, String>.from(json.decode(shareIdsJson));
        debugPrint('已加载分享码映射: $_shareIdMap');

        // 更新日历本的shareCode
        for (final entry in _shareIdMap.entries) {
          final calendarId = entry.key;
          final shareCode = entry.value;
          final index = _books.indexWhere((book) => book.id == calendarId);
          if (index != -1 && _books[index].shareCode != shareCode) {
            _books[index] = _books[index].copyWithShareCode(shareCode);
            debugPrint('已更新日历 $calendarId 的分享码: $shareCode');
          }
        }
      } catch (e) {
        debugPrint('加载分享码映射失败: $e');
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

  //添加日程到本地数据库功能
  Future<void> addSchedule(String calendarId, ScheduleItem schedule) async {
    try {
      // 确保日历本存在
      final calendar = _books.firstWhere((book) => book.id == calendarId, orElse: () => throw Exception('日历本不存在'));
      // 使用数据库插入日程
      await _dbHelper.insertSchedule(schedule);
      // 更新日历本的最后更新时间
      _lastUpdateTimeMap[calendarId] = DateTime.now();
      // 通知监听器数据已更新
      notifyListeners();
    } catch (e) {
      debugPrint('添加日程失败: $e');
      rethrow;
    }
  }

  // 从数据库加载日历本的更新时间
  Future<void> _loadCalendarUpdateTimes() async {
    try {
      debugPrint('开始从数据库加载日历本更新时间');

      // 遍历所有日历本
      for (final book in _books) {
        // 如果缓存中没有该日历本的更新时间，则使用日历本自身的更新时间
        if (!_lastUpdateTimeMap.containsKey(book.id)) {
          _lastUpdateTimeMap[book.id] = book.updatedAt;
          debugPrint('已加载日历 ${book.id} 的更新时间: ${book.updatedAt}');
        }
      }

      debugPrint('已完成所有日历本更新时间的加载');
    } catch (e) {
      debugPrint('加载日历本更新时间失败: $e');
    }
  }

  // 获取日历本的分享码
  String? getShareCode(String calendarId) {
    try {
      // 首先从日历本对象中获取
      final book = _books.firstWhere((book) => book.id == calendarId);
      if (book.shareCode != null) {
        return book.shareCode;
      }

      // 如果日历本对象中没有，尝试从映射中获取
      return _shareIdMap[calendarId];
    } catch (e) {
      debugPrint('获取日历本分享码失败: $e');
      return null;
    }
  }
}
