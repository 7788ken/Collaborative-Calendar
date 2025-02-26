import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/calendar_book.dart';
import 'database/database_helper.dart';

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

  // 获取日历的分享ID
  String getShareId(String bookId) {
    final book = _books.firstWhere((book) => book.id == bookId);
    return book.generateShareId();
  }
} 