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
        calendarBook = _books.firstWhere(
          (book) => book.id == calendarId,
        );
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
      
      // 异步刷新最后修改时间，添加超时保护
      try {
        // 使用超时保护，防止长时间阻塞
        final lastUpdateTime = await _apiService.getCalendarLastUpdateTime(shareCode)
            .timeout(const Duration(seconds: 15), onTimeout: () {
          debugPrint('获取日历 $calendarId 的最后修改时间超时');
          return null;
        });
        
        if (lastUpdateTime != null) {
          // 检查是否有更新（时间不同或者之前没有记录时间）
          bool hasUpdate = currentUpdateTime == null || 
                          lastUpdateTime.isAfter(currentUpdateTime);
          
          if (hasUpdate) {
            debugPrint('检测到日历 $calendarId 有更新，最新时间: $lastUpdateTime，之前时间: $currentUpdateTime');
            // 更新本地缓存的时间
            _lastUpdateTimeMap[calendarId] = lastUpdateTime;
            
            // 触发自动拉取日程操作
            _autoFetchCalendarSchedules(calendarId, shareCode);
          } else {
            debugPrint('日历 $calendarId 没有更新，最新时间: $lastUpdateTime');
            _lastUpdateTimeMap[calendarId] = lastUpdateTime;
          }
          
          // 通知监听器更新UI
          notifyListeners();
        } else {
          debugPrint('未能获取日历 $calendarId 的有效最后修改时间');
        }
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
      fetchSharedCalendarUpdates(calendarId).then((_) {
        debugPrint('自动拉取日历 $calendarId 日程数据成功');
      }).catchError((error) {
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
      final calendarBook = _books.firstWhere(
        (book) => book.id == calendarId && book.isShared,
        orElse: () => throw Exception('找不到共享日历本: $calendarId'),
      );
      
      // 获取分享码
      final shareCode = getShareId(calendarId);
      if (shareCode == null) {
        debugPrint('无法找到日历 $calendarId 的分享码');
        return false;
      }
      
      // 获取当前缓存的最后更新时间
      final currentUpdateTime = _lastUpdateTimeMap[calendarId];
      
      // 获取服务器最新的更新时间
      final lastUpdateTime = await _apiService.getCalendarLastUpdateTime(shareCode);
      
      // 如果有更新或者没有记录过时间，则拉取数据
      if (lastUpdateTime != null && 
          (currentUpdateTime == null || lastUpdateTime.isAfter(currentUpdateTime))) {
        debugPrint('检测到日历 $calendarId 有更新，开始拉取数据');
        
        // 更新缓存的时间
        _lastUpdateTimeMap[calendarId] = lastUpdateTime;
        notifyListeners();
        
        // 拉取最新数据
        await fetchSharedCalendarUpdates(calendarId);
        return true;
      } else {
        debugPrint('日历 $calendarId 没有检测到更新，跳过拉取');
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
          
          // 获取服务器最新的更新时间
          final lastUpdateTime = await _apiService.getCalendarLastUpdateTime(shareCode)
              .timeout(const Duration(seconds: 15), onTimeout: () {
            debugPrint('获取日历 $calendarId 的最后修改时间超时');
            return null;
          });
          
          if (lastUpdateTime != null) {
            // 检查是否有更新（时间不同或者之前没有记录时间）
            bool hasUpdate = currentUpdateTime == null || 
                            lastUpdateTime.isAfter(currentUpdateTime);
            
            // 更新缓存的时间
            _lastUpdateTimeMap[calendarId] = lastUpdateTime;
            
            if (hasUpdate) {
              debugPrint('检测到日历 $calendarId 有更新，最新时间: $lastUpdateTime，之前时间: $currentUpdateTime');
              
              // 触发自动拉取日程操作
              _autoFetchCalendarSchedules(calendarId, shareCode);
            } else {
              debugPrint('日历 $calendarId 没有更新，最新时间: $lastUpdateTime');
            }
          } else {
            debugPrint('未能获取日历 $calendarId 的有效最后修改时间');
            failureCount++;
            failedCalendarIds.add(calendarId);
            continue;
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
        
        // 异步检查并获取最新数据，不阻塞UI
        checkAndFetchCalendarUpdates(id).then((updated) {
          if (updated) {
            debugPrint('成功拉取共享日历 $id 的最新数据');
          } else {
            debugPrint('共享日历 $id 没有检测到更新或拉取失败');
          }
        }).catchError((error) {
          debugPrint('检查共享日历 $id 更新时出错: $error');
        });
      }
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

  // 分享日历到云端
  Future<String> shareCalendarToCloud(String calendarId) async {
    try {
      // 获取日历本信息
      final calendarBook = _books.firstWhere(
        (book) => book.id == calendarId,
        orElse: () => throw Exception('找不到日历本: $calendarId'),
      );
      
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
      final calendarBook = CalendarBook(
        id: calendarId,
        name: calendarData['name'],
        color: Color(colorValue),
        isShared: true,
        ownerId: calendarData['ownerId'],
      );
      
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
            
            final startDateTime = startTime is int 
                ? DateTime.fromMillisecondsSinceEpoch(startTime) 
                : DateTime.parse(startTime.toString());
                
            final endDateTime = endTime is int 
                ? DateTime.fromMillisecondsSinceEpoch(endTime) 
                : DateTime.parse(endTime.toString());
            
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
          'is_deleted': 0 // 默认未删除
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
        final result = await _apiService.syncSchedules(shareCode, syncData)
            .timeout(const Duration(seconds: 30), onTimeout: () {
          debugPrint('CalendarBookManager: 同步请求超时');
          return <String, dynamic>{'success': false, 'message': '同步请求超时'};
        });
        
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
      final scheduleData = {
        'id': schedule.id,
        'title': schedule.title,
        'description': schedule.description,
        'location': schedule.location,
        'startTime': schedule.startTime.millisecondsSinceEpoch,
        'endTime': schedule.endTime.millisecondsSinceEpoch,
        'isAllDay': schedule.isAllDay ? 1 : 0,
        'isCompleted': schedule.isCompleted ? 1 : 0
      };
      
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
  Future<void> fetchSharedCalendarUpdates(String calendarId) async {
    try {
      debugPrint('开始从云端获取日历更新，日历ID: $calendarId');
      
      // 确保是共享日历
      final calendarBook = _books.firstWhere(
        (book) => book.id == calendarId && book.isShared,
        orElse: () => throw Exception('找不到共享日历本: $calendarId'),
      );
      
      // 获取分享码
      final shareCode = getShareId(calendarId);
      if (shareCode == null) {
        throw Exception('找不到日历本的分享码');
      }
      
      debugPrint('获取到分享码: $shareCode');
      
      // 从API获取最新日历信息，如有需要更新日历数据
      final calendarData = await _apiService.getSharedCalendar(shareCode);
      
      // 检查日历本信息是否需要更新
      final name = calendarData['name'] as String;
      final colorHex = calendarData['color'] as String;
      final colorValue = int.parse(colorHex, radix: 16);
      
      if (name != calendarBook.name || colorValue != calendarBook.color.value) {
        // 更新日历本信息
        await updateBookNameAndColor(calendarId, name, Color(colorValue));
        debugPrint('已更新日历本信息: 名称=$name, 颜色=$colorHex');
      }
      
      // 获取当前日历的所有日程用于后续比较
      final existingSchedules = await _dbHelper.getSchedules(calendarId);
      debugPrint('当前日历中有 ${existingSchedules.length} 个日程');
      
      // 从API获取最新日程
      final schedulesData = await _apiService.getSchedules(shareCode);
      debugPrint('从服务器获取到 ${schedulesData.length} 个日程');
      
      // 保存当前任务完成状态，以便在导入新数据后恢复
      final taskCompletionStatus = await _getTaskStatusForCalendar(calendarId);
      debugPrint('已保存 ${taskCompletionStatus.length} 个任务完成状态记录');
      
      // 清除旧的日程
      await _dbHelper.deleteAllSchedulesInCalendar(calendarId);
      debugPrint('已清除旧的日程数据');
      
      // 准备用于保存任务完成状态的SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      // 保存新的日程
      for (var scheduleData in schedulesData) {
        try {
          // 确保日期字段是整数时间戳
          final startTime = scheduleData['startTime'];
          final endTime = scheduleData['endTime'];
          final scheduleId = scheduleData['id'];
          
          if (startTime == null || endTime == null || scheduleId == null) {
            debugPrint('警告: 日程数据不完整，跳过: $scheduleData');
            continue;
          }
          
          final startDateTime = startTime is int 
              ? DateTime.fromMillisecondsSinceEpoch(startTime) 
              : DateTime.parse(startTime.toString());
              
          final endDateTime = endTime is int 
              ? DateTime.fromMillisecondsSinceEpoch(endTime) 
              : DateTime.parse(endTime.toString());
          
          // 获取服务器返回的完成状态
          final serverCompleted = scheduleData['isCompleted'] == true;
          
          // 生成任务键
          final taskKey = '${startDateTime.year}-${startDateTime.month}-${startDateTime.day}-$scheduleId';
          
          // 检查本地是否有此任务的完成状态记录
          final localCompleted = taskCompletionStatus[taskKey] ?? false;
          
          // 决定使用哪个完成状态 - 优先使用服务器的状态
          final finalCompleted = serverCompleted;
          
          final schedule = ScheduleItem(
            id: scheduleId,
            calendarId: calendarId,
            title: scheduleData['title'],
            description: scheduleData['description'],
            startTime: startDateTime,
            endTime: endDateTime,
            isAllDay: scheduleData['isAllDay'] == 1,
            location: scheduleData['location'],
            isCompleted: finalCompleted,
          );
          
          await _dbHelper.insertSchedule(schedule);
          
          // 更新SharedPreferences中的任务完成状态
          if (finalCompleted) {
            await prefs.setBool('task_$taskKey', true);
          } else {
            // 如果任务未完成但存在记录，则删除记录
            if (prefs.containsKey('task_$taskKey')) {
              await prefs.remove('task_$taskKey');
            }
          }
          
          debugPrint('成功保存日程: ${schedule.title}, 完成状态: $finalCompleted');
        } catch (e) {
          debugPrint('保存单个日程时出错: $e');
          // 继续处理其他日程
        }
      }
      
      debugPrint('成功从云端获取最新日程数据');
      notifyListeners();
    } catch (e) {
      debugPrint('从云端获取最新日程数据失败: $e');
      rethrow;
    }
  }
  
  // 获取指定日历的所有任务完成状态
  Future<Map<String, bool>> _getTaskStatusForCalendar(String calendarId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final Map<String, bool> result = {};
      
      // 获取此日历下所有日程，用于生成有效的任务键
      final schedules = await _dbHelper.getSchedules(calendarId);
      final validPrefixes = <String>{};
      
      for (final schedule in schedules) {
        final prefix = '${schedule.startTime.year}-${schedule.startTime.month}-${schedule.startTime.day}-${schedule.id}';
        validPrefixes.add(prefix);
      }
      
      // 筛选出属于这个日历的任务状态
      for (final key in allKeys) {
        if (key.startsWith('task_')) {
          final taskKey = key.substring(5); // 去掉前缀'task_'
          
          // 检查任务键是否属于此日历
          for (final prefix in validPrefixes) {
            if (taskKey == prefix) {
              result[taskKey] = prefs.getBool(key) ?? false;
              break;
            }
          }
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
  Future<bool> syncSpecificTask(String shareCode, String scheduleId, bool isCompleted) async {
    try {
      // 参数校验
      if (shareCode.isEmpty) {
        debugPrint('错误: 分享码为空');
        return false;
      }
      
      if (scheduleId.isEmpty) {
        debugPrint('错误: 日程ID为空');
        return false;
      }
      
      debugPrint('开始直接同步特定任务: ID=$scheduleId, 完成状态=${isCompleted ? "已完成" : "未完成"}');
      debugPrint('使用分享码: $shareCode');
      
      // 获取任务数据
      final dbHelper = DatabaseHelper();
      Map<String, dynamic>? taskData;
      
      try {
      final database = await dbHelper.database;
      
      final List<Map<String, dynamic>> maps = await database.query(
        'schedules',
        where: 'id = ?',
        whereArgs: [scheduleId],
      );
      
      if (maps.isEmpty) {
          debugPrint('错误: 找不到ID为 $scheduleId 的任务');
        return false;
      }
      
        taskData = maps.first;
        debugPrint('找到任务: ${taskData['title']}');
      } catch (e) {
        debugPrint('查询数据库时出错: $e');
        return false;
      }
      
      if (taskData == null) {
        debugPrint('错误: 无法获取任务数据');
        return false;
      }
      
      // 构建需要同步的任务数据
      Map<String, dynamic> syncData;
      try {
        syncData = {
        'id': taskData['id'],
          'title': taskData['title'] ?? '',
          'description': taskData['description'] ?? '',
          'location': taskData['location'] ?? '',
        'startTime': taskData['start_time'],
        'endTime': taskData['end_time'],
        'isAllDay': taskData['is_all_day'],
        'isCompleted': isCompleted ? 1 : 0,  // 确保使用整数 1/0 而不是布尔值
      };
      
        debugPrint('准备发送的数据: $syncData');
      } catch (e) {
        debugPrint('准备同步数据时出错: $e');
        return false;
      }
      
      // 使用API服务中的配置和错误处理机制
      try {
        final result = await _apiService.syncSchedules(shareCode, [syncData]);
        
        if (result['success'] == true) {
          debugPrint('同步结果: $result');
          
          // 更新本地数据库
          try {
            final database = await dbHelper.database;
        await database.update(
          'schedules',
          {'is_completed': isCompleted ? 1 : 0},
          where: 'id = ?',
          whereArgs: [scheduleId]
        );
        
            debugPrint('本地数据库已更新完成状态为: ${isCompleted ? "已完成" : "未完成"}');
            
            // 同时更新SharedPreferences中的任务完成状态记录
            try {
              final prefs = await SharedPreferences.getInstance();
              final startTime = taskData['start_time'];
              
              if (startTime != null) {
                final DateTime startDateTime = DateTime.fromMillisecondsSinceEpoch(startTime);
                final taskKey = '${startDateTime.year}-${startDateTime.month}-${startDateTime.day}-$scheduleId';
                
                if (isCompleted) {
                  await prefs.setBool('task_$taskKey', true);
                  debugPrint('SharedPreferences已更新任务状态: task_$taskKey = true');
      } else {
                  // 如果取消完成，则删除记录
                  if (prefs.containsKey('task_$taskKey')) {
                    await prefs.remove('task_$taskKey');
                    debugPrint('从SharedPreferences中删除了任务状态: task_$taskKey');
                  }
                }
              }
            } catch (e) {
              debugPrint('更新SharedPreferences中的任务状态时出错: $e');
              // 继续执行，因为数据库已经更新成功
            }
            
            return true;
          } catch (e) {
            debugPrint('更新本地数据库时出错: $e');
            // 虽然本地更新失败，但服务器同步成功，仍然返回true
            return true;
          }
        } else {
          debugPrint('同步失败，服务器返回错误: ${result['message']}');
        return false;
      }
    } catch (e) {
        debugPrint('同步请求过程中出错: $e');
      return false;
    }
    } catch (e) {
      debugPrint('直接同步特定任务时出错: $e');
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
        final defaultBook = CalendarBook(
          id: 'default',
          name: '我的日历',
          color: Colors.blue,
        );
        
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
      
      // 加载完成后，更新所有共享日历的最后修改时间
      // 使用防御性编程，确保即使更新失败也不会中断初始化
      try {
        await updateAllSharedCalendarsTimes();
      } catch (e) {
        debugPrint('更新共享日历时间失败，但继续初始化: $e');
      }
      
      // 启动定时器
      _startUpdateCheckTimer();
      
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

  @override
  void dispose() {
    // 取消定时器
    _updateCheckTimer?.cancel();
    super.dispose();
  }

  // 启动定时器，定期检查日历更新
  void _startUpdateCheckTimer() {
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
} 