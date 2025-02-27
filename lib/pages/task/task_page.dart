import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/schedule_data.dart';
import '../../data/models/schedule_item.dart' as task_models;
import '../../models/schedule_item.dart';
import '../../data/schedule_service.dart';
import '../../data/calendar_book_manager.dart';
import '../../widgets/add_schedule_page.dart';
import '../../pages/schedule/schedule_page.dart';
import 'widgets/task_item.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  // 添加刷新方法
  static void refreshTasks(BuildContext context) {
    print('调用刷新任务方法');
    final state = context.findAncestorStateOfType<_TaskPageState>();
    if (state != null) {
      print('找到TaskPage状态，刷新任务');
      state._loadTasks();
    } else {
      print('未找到TaskPage状态');
    }
  }

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  // 使用真实数据库的日程项列表
  List<ScheduleItem> _scheduleItems = [];
  bool _isLoading = true;
  String? _currentCalendarId;
  
  // 日程服务
  final ScheduleService _scheduleService = ScheduleService();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 检查日历本是否变化
    _checkCalendarChanged();
  }
  
  // 检查日历是否变化
  void _checkCalendarChanged() {
    final calendarManager = Provider.of<CalendarBookManager>(
      context, 
      listen: false
    );
    final activeCalendarId = calendarManager.activeBook?.id;
    
    if (activeCalendarId != _currentCalendarId) {
      _currentCalendarId = activeCalendarId;
      _loadTasks();
    }
  }

  // 加载任务数据
  Future<void> _loadTasks() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 获取当前活跃的日历ID
      final calendarManager = Provider.of<CalendarBookManager>(
        context, 
        listen: false
      );
      final activeCalendarId = calendarManager.activeBook?.id;
      
      if (activeCalendarId == null) {
        setState(() {
          _scheduleItems = [];
          _isLoading = false;
        });
        return;
      }
      
      // 获取当前日历的所有日程
      final now = DateTime.now();
      // 获取从现在开始的未来日程
      final items = await _scheduleService.getSchedulesInRange(
        activeCalendarId,
        now, 
        now.add(const Duration(days: 365)), // 获取未来一年的日程
      );
      
      print('任务页面: 加载了 ${items.length} 条日程数据');
      
      if (mounted) {
        setState(() {
          _scheduleItems = items;
          _isLoading = false;
          _currentCalendarId = activeCalendarId;
        });
      }
    } catch (e) {
      print('加载任务数据出错: $e');
      if (mounted) {
        setState(() {
          _scheduleItems = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载任务失败: $e')),
        );
      }
    }
  }

  // 将日历日程项转换为任务日程项，用于显示
  task_models.ScheduleItem _convertToTaskItem(ScheduleItem item) {
    return task_models.ScheduleItem(
      title: item.title,
      startTime: '${item.startTime.hour.toString().padLeft(2, '0')}:${item.startTime.minute.toString().padLeft(2, '0')}',
      endTime: '${item.endTime.hour.toString().padLeft(2, '0')}:${item.endTime.minute.toString().padLeft(2, '0')}',
      location: item.location ?? '',
      remark: item.description ?? '',
      date: DateTime(item.startTime.year, item.startTime.month, item.startTime.day),
      isCompleted: false, // 默认未完成
    );
  }

  Map<DateTime, List<task_models.ScheduleItem>> _groupSchedulesByDate(List<ScheduleItem> items) {
    final grouped = <DateTime, List<task_models.ScheduleItem>>{};
    
    for (var item in items) {
      final date = DateTime(
        item.startTime.year, 
        item.startTime.month, 
        item.startTime.day
      );
      
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      
      grouped[date]!.add(_convertToTaskItem(item));
    }
    
    return Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key))
    );
  }

  String _getWeekday(int weekday) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[weekday - 1];
  }

  void _deleteSchedule(task_models.ScheduleItem taskItem) {
    // 查找对应的原始日程项
    final originalItem = _scheduleItems.firstWhere(
      (item) => DateTime(
        item.startTime.year, 
        item.startTime.month, 
        item.startTime.day
      ) == taskItem.date && 
      item.title == taskItem.title,
      orElse: () => ScheduleItem(id: '', calendarId: '', title: '', startTime: DateTime.now(), endTime: DateTime.now()),
    );
    
    if (originalItem.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到对应的日程')),
      );
      return;
    }
    
    // 显示确认对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除日程'),
        content: Text('确定要删除"${taskItem.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              setState(() {
                _isLoading = true;
              });
              
              try {
                // 调用服务删除日程
                await _scheduleService.deleteSchedule(originalItem.id);
                
                if (mounted) {
                  setState(() {
                    _scheduleItems.remove(originalItem);
                    _isLoading = false;
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('日程已删除')),
                  );
                }
              } catch (e) {
                print('删除日程失败: $e');
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _toggleComplete(task_models.ScheduleItem taskItem) {
    // 更新UI状态
    setState(() {
      taskItem.isCompleted = !taskItem.isCompleted;
    });
    
    // 把状态变更持久化到本地存储
    // 这里可以使用SharedPreferences或其他本地存储方式
    // 创建一个唯一标识符，基于日期和任务标题
    final String taskKey = '${taskItem.date.year}-${taskItem.date.month}-${taskItem.date.day}-${taskItem.title}';
    
    // 使用Provider存储状态
    final scheduleData = Provider.of<ScheduleData>(context, listen: false);
    scheduleData.updateTaskCompletionStatus(taskKey, taskItem.isCompleted);
    
    // 刷新日历页面，以显示更新后的统计数据
    SchedulePage.refreshSchedules(context);
  }
  
  // 编辑日程
  void _editSchedule(ScheduleItem scheduleItem) {
    // 显示日程编辑页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSchedulePage(scheduleItem: scheduleItem),
      ),
    ).then((result) {
      // 如果编辑成功，刷新任务列表
      if (result == true) {
        _loadTasks();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 添加日历变化监听
    return Consumer<CalendarBookManager>(
      builder: (context, calendarManager, child) {
        // 检查日历是否变化
        final activeCalendarId = calendarManager.activeBook?.id;
        if (activeCalendarId != _currentCalendarId && !_isLoading) {
          // 在下一帧刷新，避免在build过程中调用setState
          Future.microtask(() {
            _currentCalendarId = activeCalendarId;
            _loadTasks();
          });
        }
        
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final groupedSchedules = _groupSchedulesByDate(_scheduleItems);

        if (groupedSchedules.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_note,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无日程',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '点击顶部"+"按钮添加新日程',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadTasks,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedSchedules.length,
            itemBuilder: (context, index) {
              final date = groupedSchedules.keys.elementAt(index);
              final schedules = groupedSchedules[date]!;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日期标题
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${date.month}月${date.day}日',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getWeekday(date.weekday),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 日程列表
                  ...schedules.map((item) => TaskItemWidget(
                    item: item,
                    onToggleComplete: () => _toggleComplete(item),
                    onDelete: () => _deleteSchedule(item),
                    onEdit: (scheduleItem) => _editSchedule(scheduleItem),
                  )).toList(),
                  // 分隔线
                  if (index < groupedSchedules.length - 1)
                    const Divider(height: 32),
                ],
              );
            },
          ),
        );
      }
    );
  }
} 