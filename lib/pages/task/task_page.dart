import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../data/schedule_data.dart';
import '../../data/models/schedule_item.dart' as task_models;
import '../../models/schedule_item.dart';
import '../../data/schedule_service.dart';
import '../../data/calendar_book_manager.dart';
import '../../widgets/add_schedule_page.dart';
import '../../pages/schedule/schedule_page.dart';
import 'widgets/task_item.dart';
import '../../services/task_completion_service.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  // 添加全局Key以便在任何地方刷新
  static final GlobalKey<_TaskPageState> globalKey = GlobalKey<_TaskPageState>();

  // 添加刷新方法
  static void refreshTasks(BuildContext context) {
    print('调用刷新任务方法');
    
    // 优先通过全局Key刷新
    if (globalKey.currentState != null) {
      print('通过GlobalKey找到TaskPage状态，强制刷新任务');
      globalKey.currentState!.reloadTasks();
      return;
    }
    
    // 检查context是否仍然有效
    if (!context.mounted) {
      print('context已经不再挂载，跳过刷新');
      return;
    }
    
    // 备用方法：通过context查找状态
    try {
      final state = context.findAncestorStateOfType<_TaskPageState>();
      if (state != null) {
        print('找到TaskPage状态，刷新任务');
        // 使用Future.microtask确保在当前帧渲染完成后执行刷新
        Future.microtask(() {
          state._loadTasks().then((_) {
            // 任务刷新完成后，确保日历页面也刷新
            print('任务刷新完成，再次确保日历页面刷新');
            if (context.mounted) {  // 再次检查context是否有效
              Future.delayed(Duration(milliseconds: 50), () {
                SchedulePage.refreshSchedules(context);
              });
            }
          });
        });
      } else {
        print('未找到TaskPage状态');
      }
    } catch (e) {
      print('刷新任务时出错: $e');
      // 错误发生时不做任何操作，避免应用崩溃
    }
  }

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  // 使用真实数据库的日程项列表
  List<ScheduleItem> _scheduleItems = [];
  List<ScheduleItem> _filteredItems = []; // 过滤后的任务列表
  bool _isLoading = true;
  String? _currentCalendarId;
  
  // 添加ScrollController来控制列表滚动位置
  final ScrollController _scrollController = ScrollController();
  
  // 搜索和筛选状态
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  FilterStatus _filterStatus = FilterStatus.all;
  bool _showExpired = false; // 是否显示过期任务，默认不筛选
  
  // 日程服务
  final ScheduleService _scheduleService = ScheduleService();
  
  // 暴露给GlobalKey使用的公开方法
  void reloadTasks() {
    _loadTasks();
  }

  @override
  void initState() {
    super.initState();
    // 添加搜索文本监听
    _searchController.addListener(_onSearchChanged);
    _loadTasks();
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose(); // 释放ScrollController
    super.dispose();
  }
  
  // 搜索文本变化
  void _onSearchChanged() {
    setState(() {
      _searchText = _searchController.text;
      _applyFilters();
    });
  }
  
  // 应用筛选条件
  void _applyFilters() {
    if (_scheduleItems.isEmpty) {
      _filteredItems = [];
      return;
    }
    
    // 根据搜索文本和筛选状态过滤
    _filteredItems = _scheduleItems.where((item) {
      // 获取任务完成状态
      final scheduleData = Provider.of<ScheduleData>(context, listen: false);
      final taskKey = '${item.startTime.year}-${item.startTime.month}-${item.startTime.day}-${item.id}';
      final isCompleted = scheduleData.getTaskCompletionStatus(taskKey);
      
      // 是否过期
      final date = DateTime(item.startTime.year, item.startTime.month, item.startTime.day);
      final isExpired = _isPast(date) && !_isToday(date);
      
      // 按过期状态筛选
      if (_filterStatus == FilterStatus.expired && !isExpired) {
        return false;
      }
      
      // 按完成状态筛选
      if (_filterStatus == FilterStatus.completed && !isCompleted) {
        return false;
      }
      if (_filterStatus == FilterStatus.uncompleted && isCompleted) {
        return false;
      }
      
      // 根据_showExpired筛选过期任务
      if (!_showExpired && isExpired && _filterStatus != FilterStatus.expired) {
        return false;
      }
      
      // 关键字搜索
      if (_searchText.isNotEmpty) {
        final searchLower = _searchText.toLowerCase();
        final titleMatch = item.title.toLowerCase().contains(searchLower);
        final locationMatch = (item.location ?? '').toLowerCase().contains(searchLower);
        final descMatch = (item.description ?? '').toLowerCase().contains(searchLower);
        
        return titleMatch || locationMatch || descMatch;
      }
      
      return true;
    }).toList();
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
          _filteredItems = [];
          _isLoading = false;
        });
        return;
      }
      
      // 获取所有日程，不限制时间范围
      // 使用一个较早的过去日期和较远的未来日期以包含所有日程
      final pastDate = DateTime(2000, 1, 1); // 过去的日期
      final futureDate = DateTime.now().add(const Duration(days: 3650)); // 未来10年
      
      final items = await _scheduleService.getSchedulesInRange(
        activeCalendarId,
        pastDate, 
        futureDate,
      );
      
      print('任务页面: 加载了 ${items.length} 条日程数据');
      
      if (mounted) {
        setState(() {
          _scheduleItems = items;
          _isLoading = false;
          _currentCalendarId = activeCalendarId;
          _applyFilters(); // 应用过滤
        });
      }
    } catch (e) {
      print('加载任务数据出错: $e');
      if (mounted) {
        setState(() {
          _scheduleItems = [];
          _filteredItems = [];
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
    // 获取任务完成状态
    final scheduleData = Provider.of<ScheduleData>(
      context, 
      listen: false
    );
    
    // 使用与其他地方一致的方式生成任务键
    final String taskKey = '${item.startTime.year}-${item.startTime.month}-${item.startTime.day}-${item.id}';
    
    // 获取已保存的完成状态
    final isCompleted = scheduleData.getTaskCompletionStatus(taskKey);
    
    return task_models.ScheduleItem(
      title: item.title,
      startTime: '${item.startTime.hour.toString().padLeft(2, '0')}:${item.startTime.minute.toString().padLeft(2, '0')}',
      endTime: '${item.endTime.hour.toString().padLeft(2, '0')}:${item.endTime.minute.toString().padLeft(2, '0')}',
      location: item.location ?? '',
      remark: item.description ?? '',
      date: DateTime(item.startTime.year, item.startTime.month, item.startTime.day),
      isCompleted: isCompleted, // 使用已保存的完成状态
      isSynced: item.isSynced, // 添加同步状态
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
    print('准备删除任务: ${taskItem.title}');
    
    // 找到对应的原始日程项
    final originalItem = _findOriginalScheduleItem(taskItem);
    if (originalItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到对应的日程')),
      );
      return;
    }
    
    // 保存当前滚动位置
    final double? currentScrollPosition = _scrollController.hasClients ? _scrollController.offset : null;
    
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
              
              try {
                // 生成任务键，用于从状态管理中移除
                final String taskKey = '${originalItem.startTime.year}-${originalItem.startTime.month}-${originalItem.startTime.day}-${originalItem.id}';
                
                // 获取日历管理器，用于获取分享码
                final calendarManager = Provider.of<CalendarBookManager>(context, listen: false);
                final shareCode = calendarManager.getShareId(originalItem.calendarId);
                
                // 调用服务删除日程
                await _scheduleService.deleteSchedule(originalItem.id);
                
                if (mounted) {
                  // 获取ScheduleData实例
                  final scheduleData = Provider.of<ScheduleData>(context, listen: false);
                  
                  // 如果任务有完成状态记录，更新状态（设为false或移除）
                  if (scheduleData.getTaskCompletionStatus(taskKey)) {
                    // 添加振动反馈
                    HapticFeedback.lightImpact();
                    
                    // 将任务状态从系统中移除
                    scheduleData.removeTaskCompletionStatus(taskKey);
                  }
                  
                  setState(() {
                    // 从主列表中移除
                    _scheduleItems.remove(originalItem);
                    
                    // 重新应用过滤器，而不是直接修改_filteredItems
                    _applyFilters();
                  });
                  
                  // 立即刷新日历页面
                  SchedulePage.refreshSchedules(context);
                  
                  // 使用单次延迟刷新确保统计数据更新
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      SchedulePage.refreshSchedules(context);
                    }
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('日程已删除')),
                  );
                  
                  print('任务"${taskItem.title}"已删除，键值: $taskKey');
                  
                  // 恢复滚动位置
                  if (currentScrollPosition != null && _scrollController.hasClients) {
                    Future.microtask(() {
                      _scrollController.jumpTo(
                        currentScrollPosition.clamp(
                          0.0, 
                          _scrollController.position.maxScrollExtent
                        )
                      );
                    });
                  }
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
    // 保存当前滚动位置
    final double? currentScrollPosition = _scrollController.hasClients ? _scrollController.offset : null;
    
    // 找到对应的原始日程项，获取 ID
    final originalItem = _findOriginalScheduleItem(taskItem);
    if (originalItem == null) {
      print('找不到对应的原始日程项，无法更新完成状态');
      return;
    }
    
    // 更新UI状态
    setState(() {
      taskItem.isCompleted = !taskItem.isCompleted;
    });
    
    // 使用统一的任务完成状态服务
    TaskCompletionService.toggleTaskCompletion(
      context, 
      originalItem,
      onStateChanged: () {
        // 立即刷新日历页面，仅在组件挂载时执行
        if (!mounted) {
          debugPrint('任务页面：回调时组件已销毁，取消操作');
          return;
        }
        
        try {
          SchedulePage.refreshSchedules(context);
          debugPrint('任务页面：已刷新日历页面');
        } catch (e) {
          debugPrint('任务页面：刷新日历页面时出错：$e');
        }
        
        // 使用单次延迟刷新确保统计数据更新
        // 用一个safe方法包装延迟操作
        _safeDelayedRefresh();
      }
    );
  }
  
  // 安全地执行延迟刷新操作
  void _safeDelayedRefresh() {
    // 在执行延迟操作前先检查组件状态
    if (!mounted) {
      debugPrint('任务页面：延迟刷新前组件已销毁');
      return;
    }
    
    // 捕获当前的 BuildContext 以避免在回调中使用可能已被销毁的 context
    final capturedContext = context;
    
    // 执行延迟刷新
    Future.delayed(const Duration(milliseconds: 300), () {
      // 再次检查组件状态
      if (!mounted) {
        debugPrint('任务页面：延迟回调时组件已销毁，取消操作');
        return;
      }
      
      try {
        // 使用安全的方法刷新日历页面
        _safeRefreshSchedules(capturedContext);
      } catch (e) {
        debugPrint('任务页面：延迟刷新日历页面时出错：$e');
      }
      
      // 仅在组件仍然活跃时更新当前页面
      if (!mounted) return;
      
      try {
        // 记住当前筛选器状态
        final FilterStatus currentFilterStatus = _filterStatus;
        final String currentSearchText = _searchText;
        final bool currentShowExpired = _showExpired;
        
        _loadTasks().then((_) {
          // 仅在组件仍然活跃时恢复筛选器状态
          if (!mounted) return;
          
          setState(() {
            _filterStatus = currentFilterStatus;
            _searchText = currentSearchText;
            _showExpired = currentShowExpired;
            _applyFilters();
          });
        }).catchError((e) {
          debugPrint('任务页面：加载任务时出错：$e');
        });
      } catch (e) {
        debugPrint('任务页面：更新当前页面时出错：$e');
      }
    });
  }
  
  // 安全地刷新日历页面
  void _safeRefreshSchedules(BuildContext capturedContext) {
    try {
      // 确保 context 仍然有效
      if (!mounted) return;
      
      // 尝试刷新日历页面
      SchedulePage.refreshSchedules(capturedContext);
      debugPrint('任务页面：延迟刷新日历页面成功');
    } catch (e) {
      debugPrint('任务页面：刷新日历页面出错：$e');
    }
  }
  
  // 根据任务项查找对应的原始日程项
  ScheduleItem? _findOriginalScheduleItem(task_models.ScheduleItem taskItem) {
    try {
      return _scheduleItems.firstWhere(
        (item) => 
          item.title == taskItem.title && 
          DateTime(
            item.startTime.year, 
            item.startTime.month, 
            item.startTime.day
          ) == taskItem.date &&
          '${item.startTime.hour.toString().padLeft(2, '0')}:${item.startTime.minute.toString().padLeft(2, '0')}' == taskItem.startTime
      );
    } catch (e) {
      print('查找原始日程项出错: $e');
      return null;
    }
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
        print('编辑任务成功，准备刷新任务列表');
        
        // 先获取ScheduleData以便通知全局更新
        if (!mounted) return;
        final scheduleData = Provider.of<ScheduleData>(context, listen: false);
        
        // 先强制刷新ScheduleData，通知所有监听者
        scheduleData.forceRefresh();
        
        // 使用单次延迟刷新，避免多次不必要的刷新
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            // 刷新任务页面
            if (TaskPage.globalKey.currentState != null) {
              TaskPage.globalKey.currentState!.reloadTasks();
            } else {
              TaskPage.refreshTasks(context);
            }
            
            // 刷新日历页面
            if (SchedulePage.globalKey.currentState != null) {
              SchedulePage.globalKey.currentState!.reloadSchedules();
            } else {
              SchedulePage.refreshSchedules(context);
            }
            
            // 显示成功提示
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('任务已更新')),
            );
          }
        });
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
        
        // 使用过滤后的任务列表
        final groupedSchedules = _groupSchedulesByDate(_filteredItems);

        return Column(
          children: [
            // 搜索和筛选区域
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  // 搜索框
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索任务...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 筛选按钮
                  Row(
                    children: [
                      _buildFilterChip(
                        label: '全部',
                        selected: _filterStatus == FilterStatus.all,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _filterStatus = FilterStatus.all;
                              _applyFilters();
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: '已完成',
                        selected: _filterStatus == FilterStatus.completed,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _filterStatus = FilterStatus.completed;
                              _applyFilters();
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: '未完成',
                        selected: _filterStatus == FilterStatus.uncompleted,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _filterStatus = FilterStatus.uncompleted;
                              _applyFilters();
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: '已过期',
                        selected: _filterStatus == FilterStatus.expired,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _filterStatus = FilterStatus.expired;
                              _applyFilters();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 显示/隐藏过期任务的开关
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        child: Switch(
                          value: _showExpired,
                          onChanged: (value) {
                            // 保存当前滚动位置
                            final double? currentScrollPosition = 
                                _scrollController.hasClients ? _scrollController.offset : null;
                              
                            setState(() {
                              _showExpired = value;
                              _applyFilters();
                            });
                            
                            // 恢复滚动位置
                            if (currentScrollPosition != null && _scrollController.hasClients) {
                              Future.microtask(() {
                                if (_scrollController.hasClients) {
                                  _scrollController.jumpTo(
                                    currentScrollPosition.clamp(
                                      0.0, 
                                      _scrollController.position.maxScrollExtent
                                    )
                                  );
                                }
                              });
                            }
                          },
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showExpired ? "隐藏过期任务" : "显示过期任务",
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 任务列表
            Expanded(
              child: groupedSchedules.isEmpty
                ? Center(
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
                          '没有找到匹配的任务',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        if (_searchText.isNotEmpty || _filterStatus != FilterStatus.all) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _filterStatus = FilterStatus.all;
                                _showExpired = false;
                                _applyFilters();
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('清除筛选条件'),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTasks,
                    child: ListView.builder(
                      controller: _scrollController, // 添加ScrollController
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
                                      color: _isToday(date) 
                                          ? Theme.of(context).colorScheme.primary
                                          : _isPast(date) 
                                              ? Colors.grey
                                              : Theme.of(context).colorScheme.primary,
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
                                  const SizedBox(width: 8),
                                  if (_isToday(date))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '今天',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (_isPast(date) && !_isToday(date))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '已过期',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
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
                              originalId: _findOriginalScheduleItem(item)?.id ?? '',
                              isUnsynced: !item.isSynced,
                              onSyncStatusChanged: () {
                                // 重新加载任务列表
                                setState(() {
                                  _loadTasks();
                                });
                              },
                            )).toList(),
                            // 分隔线
                            if (index < groupedSchedules.length - 1)
                              const Divider(height: 32),
                          ],
                        );
                      },
                    ),
                  ),
            ),
          ],
        );
      }
    );
  }
  
  // 构建筛选选项按钮
  Widget _buildFilterChip({
    required String label, 
    required bool selected, 
    required ValueChanged<bool> onSelected
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      checkmarkColor: Colors.white,
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
  
  // 判断日期是否是今天
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
  
  // 判断日期是否已过期
  bool _isPast(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.isBefore(today);
  }
}

// 筛选状态枚举
enum FilterStatus {
  all,         // 全部
  completed,   // 已完成
  uncompleted, // 未完成
  expired,     // 已过期
} 