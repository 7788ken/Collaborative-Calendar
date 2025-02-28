import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/calendar_book.dart';
import 'database/database_helper.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule_item.dart';

// 日历本管理类
class CalendarBookManager with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  List<CalendarBook> _books = [];
  String _activeBookId = 'default';
  static const String _activeBookIdKey = 'active_calendar_book_id';

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

  // 初始化方法
  Future<void> init() async {
    try {
      // 从数据库加载日历本列表
      _books = await _dbHelper.getCalendarBooks();
      
      // 如果没有日历本（首次运行），创建默认日历本
      if (_books.isEmpty) {
        final defaultBook = CalendarBook(
          id: 'default',
          name: '我的日历',
          color: Colors.blue,
        );
        await _dbHelper.insertCalendarBook(defaultBook);
        _books = [defaultBook];
      }
      
      // 从SharedPreferences加载上次选中的日历本ID
      final prefs = await SharedPreferences.getInstance();
      _activeBookId = prefs.getString(_activeBookIdKey) ?? 'default';
      
      // 确保选中的日历本在列表中存在，否则默认选中第一个
      if (!_books.any((book) => book.id == _activeBookId)) {
        _activeBookId = _books.first.id;
        await prefs.setString(_activeBookIdKey, _activeBookId);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('初始化日历本管理器失败: $e');
      // 错误处理，使用内存中的默认值
      _books = [
        CalendarBook(
          id: 'default',
          name: '我的日历',
          color: Colors.blue,
        ),
      ];
      _activeBookId = 'default';
    }
  }

  // 设置当前选中的日历本
  Future<void> setActiveBook(String id) async {
    if (_activeBookId != id && _books.any((book) => book.id == id)) {
      _activeBookId = id;
      
      // 保存选中状态到SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeBookIdKey, _activeBookId);
      
      notifyListeners();
    }
  }

  // 创建新日历本
  Future<void> createBook(String name, Color color) async {
    final newBook = CalendarBook(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      color: color,
    );
    
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
      final updatedBook = _books[index].copyWith(
        name: newName,
        color: newColor,
      );
      
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
      // 从数据库删除
      await _dbHelper.deleteCalendarBook(id);
      
      // 如果删除的是当前选中的日历本，则自动选择另一个
      if (_activeBookId == id) {
        final newActiveId = _books.firstWhere((b) => b.id != id).id;
        await setActiveBook(newActiveId);
      }
      
      // 更新内存中的列表
      _books.removeAt(index);
      notifyListeners();
    }
  }

  // 导入共享日历本
  Future<bool> importSharedBook(
    String shareId,
    String name,
    Color color,
    String ownerId,
  ) async {
    // 检查是否已导入
    if (_books.any((book) => book.id == shareId)) {
      return false;
    }
    
    final sharedBook = CalendarBook(
      id: shareId,
      name: name,
      color: color,
      isShared: true,
      ownerId: ownerId,
    );
    
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
  
  // 保存服务器返回的分享码
  Future<void> saveShareId(String bookId, String shareId) async {
    // 在真实应用中，这里应该将分享码保存到数据库的适当字段中
    // 目前只是保存在内存中并打印出来
    debugPrint('为日历本 $bookId 保存服务器分享码: $shareId');
    
    // 这里应该将分享码与日历本关联起来
    // 例如存储在共享日历表中或日历本表的特定字段中
    // 目前只是使用Map在内存中临时存储
    _shareIdMap[bookId] = shareId;
    
    notifyListeners();
  }
  
  // 存储分享码的临时Map（在真实应用中应该存储在数据库中）
  final Map<String, String> _shareIdMap = {};
  
  // 获取日历本的分享ID，优先使用服务器提供的分享ID，没有则使用本地生成的分享ID
  String? getShareId(String calendarId) {
    if (_shareIdMap.containsKey(calendarId)) {
      return _shareIdMap[calendarId];
    }
    return null;
  }
  
  // 复制日历本及其所有日程到一个新的本地日历本
  Future<String> copyCalendarBook(String sourceCalendarId, String newName, Color newColor) async {
    try {
      print('开始复制日历本: $sourceCalendarId');
      
      // 获取源日历本
      final sourceBook = _books.firstWhere(
        (book) => book.id == sourceCalendarId,
        orElse: () => throw Exception('找不到源日历本: $sourceCalendarId'),
      );
      
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
} 