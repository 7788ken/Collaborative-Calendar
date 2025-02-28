import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule_item.dart';
import 'models/schedule_item.dart' as task_models;

// 测试数据
class ScheduleData extends ChangeNotifier {
  List<ScheduleItem> _items = [];
  Map<String, bool> _taskCompletionStatus = {};
  bool _isLoaded = false;

  List<ScheduleItem> get items => _items;
  bool get isLoaded => _isLoaded;

  // 获取任务完成状态
  bool getTaskCompletionStatus(String taskKey) {
    return _taskCompletionStatus[taskKey] ?? false;
  }

  // 更新任务完成状态
  Future<void> updateTaskCompletionStatus(String taskKey, bool isCompleted) async {
    _taskCompletionStatus[taskKey] = isCompleted;
    // 立即通知监听者
    notifyListeners();
    
    // 保存到SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('task_$taskKey', isCompleted);
      print('任务状态已保存: $taskKey = $isCompleted');
      
      // 保存完成后再次通知，确保状态完全更新
      Future.delayed(Duration(milliseconds: 50), () {
        notifyListeners();
      });
    } catch (e) {
      print('保存任务状态时出错: $e');
    }
  }

  // 删除任务完成状态
  Future<void> removeTaskCompletionStatus(String taskKey) async {
    // 从内存中移除
    _taskCompletionStatus.remove(taskKey);
    notifyListeners();
    
    // 从SharedPreferences中移除
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('task_$taskKey');
      print('任务状态已移除: $taskKey');
    } catch (e) {
      print('移除任务状态时出错: $e');
    }
  }

  // 加载所有任务状态
  Future<void> loadTaskCompletionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      // 创建新的状态Map
      final Map<String, bool> newStatus = {};
      
      for (final key in allKeys) {
        if (key.startsWith('task_')) {
          final taskKey = key.substring(5); // 去掉前缀'task_'
          newStatus[taskKey] = prefs.getBool(key) ?? false;
        }
      }
      
      // 一次性更新，减少不必要的刷新
      _taskCompletionStatus = newStatus;
      
      print('已加载 ${_taskCompletionStatus.length} 个任务状态');
      
      // 立即通知监听者
      notifyListeners();
      
      // 延迟后再次通知，确保所有UI组件都能收到更新
      Future.delayed(Duration(milliseconds: 50), () {
        notifyListeners();
      });
    } catch (e) {
      print('加载任务状态时出错: $e');
    }
  }

  // 获取指定日期的已完成任务数量
  int getCompletedTaskCount(DateTime date) {
    final datePrefix = '${date.year}-${date.month}-${date.day}';
    
    int count = 0;
    for (final entry in _taskCompletionStatus.entries) {
      if (entry.key.startsWith(datePrefix) && entry.value) {
        count++;
      }
    }
    
    return count;
  }

  // 清理不存在任务的完成状态记录
  Future<void> cleanupTaskCompletionStatus(List<ScheduleItem> allTasks) async {
    // 创建有效的任务键集合
    final Set<String> validTaskKeys = {};
    for (final task in allTasks) {
      final taskKey = '${task.startTime.year}-${task.startTime.month}-${task.startTime.day}-${task.id}';
      validTaskKeys.add(taskKey);
    }
    
    // 找出所有无效的任务键
    final List<String> keysToRemove = [];
    for (final key in _taskCompletionStatus.keys) {
      if (!validTaskKeys.contains(key)) {
        keysToRemove.add(key);
      }
    }
    
    // 从内存中移除无效的记录
    for (final key in keysToRemove) {
      _taskCompletionStatus.remove(key);
    }
    
    // 从SharedPreferences中移除无效的记录
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in keysToRemove) {
        await prefs.remove('task_$key');
      }
      print('已清理 ${keysToRemove.length} 个无效的任务完成状态记录');
    } catch (e) {
      print('清理任务状态记录时出错: $e');
    }
    
    // 通知监听者状态变化
    notifyListeners();
  }

  // 测试数据 - 使用正确的task_models.ScheduleItem而不是日历模型
  static final List<task_models.ScheduleItem> scheduleItems = [
    // 今天的日程
    task_models.ScheduleItem(
      title: '团队周会',
      startTime: '09:00',
      endTime: '10:30',
      location: '线上会议',
      remark: '讨论本周进度和下周计划',
      date: DateTime.now(),
      isCompleted: true,
    ),
    task_models.ScheduleItem(
      title: '项目评审',
      startTime: '14:00',
      endTime: '15:00',
      location: '会议室A',
      remark: '准备项目文档和演示材料',
      date: DateTime.now(),
    ),
    
    // 明天的日程
    task_models.ScheduleItem(
      title: '客户会议',
      startTime: '10:00',
      endTime: '11:30',
      location: '咖啡厅',
      remark: '讨论新需求和合作方案',
      date: DateTime.now().add(const Duration(days: 1)),
    ),
    task_models.ScheduleItem(
      title: '技术分享会',
      startTime: '15:00',
      endTime: '16:30',
      location: '会议室B',
      remark: '分享最新的技术趋势和实践经验',
      date: DateTime.now().add(const Duration(days: 1)),
    ),
    
    // 后天的日程
    task_models.ScheduleItem(
      title: '产品设计评审',
      startTime: '09:30',
      endTime: '11:00',
      location: '设计部',
      remark: '评审新功能的设计方案',
      date: DateTime.now().add(const Duration(days: 2)),
    ),
    task_models.ScheduleItem(
      title: '团队建设活动',
      startTime: '14:30',
      endTime: '17:30',
      location: '城市公园',
      remark: '户外团建活动，请穿运动装',
      date: DateTime.now().add(const Duration(days: 2)),
    ),
    
    // 三天后的日程
    task_models.ScheduleItem(
      title: '季度总结会',
      startTime: '10:00',
      endTime: '12:00',
      location: '大会议室',
      remark: '总结本季度工作，规划下季度目标',
      date: DateTime.now().add(const Duration(days: 3)),
    ),
    
    // 四天后的日程
    task_models.ScheduleItem(
      title: '项目启动会',
      startTime: '09:00',
      endTime: '10:30',
      location: '会议室C',
      remark: '新项目启动，确定项目目标和分工',
      date: DateTime.now().add(const Duration(days: 4)),
    ),
    
    // 五天后的日程
    task_models.ScheduleItem(
      title: '培训课程',
      startTime: '13:30',
      endTime: '16:30',
      location: '培训中心',
      remark: '新技术培训课程，请带笔记本电脑',
      date: DateTime.now().add(const Duration(days: 5)),
    ),
    
    // 一周后的日程
    task_models.ScheduleItem(
      title: '战略规划会',
      startTime: '14:00',
      endTime: '17:00',
      location: '总部会议室',
      remark: '讨论下半年战略规划',
      date: DateTime.now().add(const Duration(days: 7)),
    ),
  ];

  // 强制刷新日历页面
  void forceRefresh() {
    // 仅调用通知，不做其他操作
    print('强制刷新日历页面状态');
    notifyListeners();
  }
} 