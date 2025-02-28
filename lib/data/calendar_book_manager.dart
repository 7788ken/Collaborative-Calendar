import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/calendar_book.dart';
import 'database/database_helper.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule_item.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;

// 日历本管理类
class CalendarBookManager with ChangeNotifier {
  final _dbHelper = DatabaseHelper();
  final _apiService = ApiService();
  
  List<CalendarBook> _books = [];
  String _activeBookId = 'default';
  Map<String, String> _shareIdMap = {}; // 用于存储日历本ID到分享码的映射
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
      
      // 加载分享码
      await _loadShareIds();
      
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
        await setActiveBook(newActiveId);
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
      print('开始从云端导入日历，分享码: $shareCode');
      
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
          print('发现孤立的分享码映射，正在清理: $existingCalendarId -> $shareCode');
          _shareIdMap.remove(existingCalendarId);
          shareIds.remove(existingCalendarId);
          await prefs.setString('share_ids', json.encode(shareIds));
        }
      }
      
      if (isAlreadyImported) {
        print('日历已导入，分享码: $shareCode, 日历ID: $existingCalendarId');
        return false;
      }
      
      // 从API获取日历信息
      final calendarData = await _apiService.getSharedCalendar(shareCode);
      
      print('获取到日历信息: $calendarData');
      
      // 创建日历本对象
      final colorHex = calendarData['color'] as String;
      final colorValue = int.parse(colorHex, radix: 16);
      
      final calendarId = const Uuid().v4();
      final calendarBook = CalendarBook(
        id: calendarId,
        name: calendarData['name'],
        color: Color(colorValue),
        isShared: true,
        ownerId: calendarData['ownerId'],
      );
      
      print('创建日历本对象: ${calendarBook.name}');
      
      // 保存日历本到数据库
      await _dbHelper.insertCalendarBook(calendarBook);
      
      // 保存分享码
      await saveShareId(calendarId, shareCode);
      
      print('开始获取日程数据');
      
      // 从API获取该日历下的所有日程
      final schedulesData = await _apiService.getSchedules(shareCode);
      
      print('获取到日程数据: $schedulesData');
      
      if (schedulesData != null && schedulesData.isNotEmpty) {
        // 保存日程到数据库
        for (var scheduleData in schedulesData) {
          try {
            print('处理日程: $scheduleData');
            
            // 确保日期字段是整数时间戳
            final startTime = scheduleData['startTime'];
            final endTime = scheduleData['endTime'];
            
            if (startTime == null || endTime == null) {
              print('警告: 日程缺少开始或结束时间，跳过');
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
            print('成功保存日程: ${schedule.title}, 完成状态: $isCompleted');
            
            // 如果任务已完成，同时保存完成状态到SharedPreferences
            if (isCompleted) {
              final taskKey = '${startDateTime.year}-${startDateTime.month}-${startDateTime.day}-${schedule.id}';
              await prefs.setBool('task_$taskKey', true);
              print('已保存任务完成状态到本地: $taskKey = true');
            }
          } catch (e) {
            print('保存单个日程时出错: $e');
            // 继续处理其他日程，不中断整个过程
          }
        }
      } else {
        print('没有找到日程数据或数据为空');
      }
      
      // 将新日历本添加到内存列表
      _books.add(calendarBook);
      notifyListeners();
      
      print('成功导入日历: ${calendarBook.name}');
      return true;
    } catch (e) {
      print('从云端导入日历失败: $e');
      return false;
    }
  }
  
  // 同步共享日历日程到云端
  Future<void> syncSharedCalendarSchedules(String calendarId, {String? specificScheduleId}) async {
    try {
      print('CalendarBookManager: 开始同步共享日历日程');
      
      // 获取分享码
      final shareCode = getShareId(calendarId);
      if (shareCode == null) {
        throw Exception('未找到日历本的分享码');
      }
      
      // 如果指定了特定日程ID，则只同步该日程
      if (specificScheduleId != null) {
        print('CalendarBookManager: 仅同步特定日程 ID: $specificScheduleId');
        await _syncSpecificTask(calendarId, shareCode, specificScheduleId);
        return;
      }
      
      // 否则，获取所有需要同步的日程
      print('CalendarBookManager: 获取所有需要同步的日程');
      final schedules = await _getSchedulesNeedSync(calendarId);
      
      if (schedules.isEmpty) {
        print('CalendarBookManager: 没有需要同步的日程');
        return;
      }
      
      print('CalendarBookManager: 找到 ${schedules.length} 条需要同步的日程');
      
      // 创建一个列表存储所有日程的同步数据
      final List<Map<String, dynamic>> syncData = [];
      
      // 处理每条日程数据
      for (var schedule in schedules) {
        final scheduleData = {
          'id': schedule.id,
          'title': schedule.title,
          'description': schedule.description,
          'location': schedule.location,
          'startTime': schedule.startTime.millisecondsSinceEpoch,
          'endTime': schedule.endTime.millisecondsSinceEpoch,
          'isAllDay': schedule.isAllDay ? 1 : 0,
          'isCompleted': schedule.isCompleted ? 1 : 0,
          // 在批量同步时也需要添加删除标记，虽然这种情况很少发生
          // 因为我们通常会使用单条删除API
          'is_deleted': 0 // 默认未删除
        };
        
        print('CalendarBookManager: 准备同步的日程数据: $scheduleData');
        syncData.add(scheduleData);
      }
      
      // 使用API进行批量同步
      final apiService = ApiService();
      try {
        print('CalendarBookManager: 发送批量同步请求，日程数量: ${syncData.length}');
        final result = await apiService.syncSchedules(shareCode, syncData);
        print('CalendarBookManager: 同步成功，服务器响应: $result');
        
        // 更新已同步的日程状态
        await _updateSyncStatus(calendarId, schedules);
        
      } catch (e) {
        print('CalendarBookManager: 同步请求失败: $e');
        rethrow;
      }
    } catch (e) {
      print('CalendarBookManager: 同步共享日历日程错误: $e');
      rethrow;
    }
  }
  
  // 同步单个特定日程
  Future<void> _syncSpecificTask(String calendarId, String shareCode, String scheduleId) async {
    try {
      print('CalendarBookManager: 开始同步特定日程 ID: $scheduleId');
      
      // 获取日程数据
      final schedules = await _dbHelper.getScheduleById(scheduleId);
      if (schedules.isEmpty) {
        // 如果本地找不到该日程，可能是已被删除，但我们现在使用专门的API删除日程
        // 所以这里不再需要发送删除标记
        print('CalendarBookManager: 本地未找到日程，可能已被删除');
        print('CalendarBookManager: 跳过同步，因为删除操作应该已经通过专门的API完成');
        return;
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
      
      print('CalendarBookManager: 准备同步的日程数据: $scheduleData');
      
      // 使用API进行同步
      final apiService = ApiService();
      await apiService.syncSchedules(shareCode, [scheduleData]);
      print('CalendarBookManager: 特定日程同步成功');
      
      // 更新已同步状态 - 使用正确的方法名
      await _dbHelper.updateScheduleSyncStatus(schedule.id, true);
    } catch (e) {
      print('CalendarBookManager: 同步特定日程错误: $e');
      rethrow;
    }
  }
  
  // 获取需要同步的日程
  Future<List<ScheduleItem>> _getSchedulesNeedSync(String calendarId) async {
    try {
      // 获取最近修改的日程
      return await _dbHelper.getRecentlyModifiedSchedules(calendarId);
    } catch (e) {
      print('CalendarBookManager: 获取需要同步的日程错误: $e');
      return [];
    }
  }
  
  // 更新日程的同步状态
  Future<void> _updateSyncStatus(String calendarId, List<ScheduleItem> schedules) async {
    try {
      for (var schedule in schedules) {
        await _dbHelper.updateScheduleSyncStatus(schedule.id, true);
      }
      print('CalendarBookManager: 已更新${schedules.length}条日程的同步状态');
    } catch (e) {
      print('CalendarBookManager: 更新同步状态错误: $e');
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
      
      print('已加载 ${taskStatus.length} 个任务状态用于同步');
      return taskStatus;
    } catch (e) {
      print('加载任务状态时出错: $e');
      return {}; // 返回空Map避免同步失败
    }
  }
  
  // 从云端下载最新的日程数据
  Future<void> fetchSharedCalendarUpdates(String calendarId) async {
    try {
      print('开始从云端获取日历更新，日历ID: $calendarId');
      
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
      
      print('获取到分享码: $shareCode');
      
      // 从API获取最新日历信息，如有需要更新日历数据
      final calendarData = await _apiService.getSharedCalendar(shareCode);
      
      // 检查日历本信息是否需要更新
      final name = calendarData['name'] as String;
      final colorHex = calendarData['color'] as String;
      final colorValue = int.parse(colorHex, radix: 16);
      
      if (name != calendarBook.name || colorValue != calendarBook.color.value) {
        // 更新日历本信息
        await updateBookNameAndColor(calendarId, name, Color(colorValue));
        print('已更新日历本信息: 名称=$name, 颜色=$colorHex');
      }
      
      // 获取当前日历的所有日程用于后续比较
      final existingSchedules = await _dbHelper.getSchedules(calendarId);
      print('当前日历中有 ${existingSchedules.length} 个日程');
      
      // 从API获取最新日程
      final schedulesData = await _apiService.getSchedules(shareCode);
      print('从服务器获取到 ${schedulesData.length} 个日程');
      
      // 保存当前任务完成状态，以便在导入新数据后恢复
      final taskCompletionStatus = await _getTaskStatusForCalendar(calendarId);
      print('已保存 ${taskCompletionStatus.length} 个任务完成状态记录');
      
      // 清除旧的日程
      await _dbHelper.deleteAllSchedulesInCalendar(calendarId);
      print('已清除旧的日程数据');
      
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
            print('警告: 日程数据不完整，跳过: $scheduleData');
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
          
          print('成功保存日程: ${schedule.title}, 完成状态: $finalCompleted');
        } catch (e) {
          print('保存单个日程时出错: $e');
          // 继续处理其他日程
        }
      }
      
      print('成功从云端获取最新日程数据');
      notifyListeners();
    } catch (e) {
      print('从云端获取最新日程数据失败: $e');
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
      
      print('获取到日历 $calendarId 的任务完成状态: ${result.length} 条记录');
      return result;
    } catch (e) {
      print('获取任务完成状态时出错: $e');
      return {}; // 返回空Map，避免操作失败
    }
  }

  // 添加测试方法：直接同步特定任务ID的完成状态
  Future<bool> syncSpecificTask(String shareCode, String scheduleId, bool isCompleted) async {
    try {
      print('开始直接同步特定任务: ID=$scheduleId, 完成状态=${isCompleted ? "已完成" : "未完成"}');
      print('使用分享码: $shareCode');
      
      // 获取任务数据
      final dbHelper = DatabaseHelper();
      final database = await dbHelper.database;
      
      final List<Map<String, dynamic>> maps = await database.query(
        'schedules',
        where: 'id = ?',
        whereArgs: [scheduleId],
      );
      
      if (maps.isEmpty) {
        print('错误: 找不到ID为 $scheduleId 的任务');
        return false;
      }
      
      final taskData = maps.first;
      print('找到任务: ${taskData['title']}');
      
      // 构建需要同步的任务数据
      final Map<String, dynamic> syncData = {
        'id': taskData['id'],
        'title': taskData['title'],
        'description': taskData['description'],
        'location': taskData['location'],
        'startTime': taskData['start_time'],
        'endTime': taskData['end_time'],
        'isAllDay': taskData['is_all_day'],
        'isCompleted': isCompleted ? 1 : 0,  // 确保使用整数 1/0 而不是布尔值
      };
      
      print('准备发送的数据: $syncData');
      
      // 使用API服务中的配置
      final String baseUrl = 'http://localhost:3002';
      
      // 发送到服务器
      final url = '$baseUrl/api/calendars/$shareCode/sync';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'changes': [syncData]
        }),
      );
      
      print('服务器响应状态码: ${response.statusCode}');
      print('服务器响应内容: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('同步结果: $responseData');
        
        // 同时更新本地数据库的完成状态
        await database.update(
          'schedules',
          {'is_completed': isCompleted ? 1 : 0},
          where: 'id = ?',
          whereArgs: [scheduleId]
        );
        
        print('本地数据库已更新完成状态为: ${isCompleted ? "已完成" : "未完成"}');
        
        return responseData['success'] == true;
      } else {
        print('同步失败，服务器返回错误: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('直接同步特定任务时出错: $e');
      return false;
    }
  }
} 