import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/schedule_data.dart';
import '../../data/schedule_data_migrator.dart';
import '../../data/schedule_service.dart';
import '../../models/schedule_item.dart';
import '../../data/calendar_book_manager.dart';
import 'widgets/calendar_grid.dart';
import 'widgets/schedule_item.dart' as ui;
import 'widgets/add_schedule_sheet.dart';
import 'widgets/edit_schedule_sheet.dart';
import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../services/task_completion_service.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  // 添加全局Key以便在任何地方刷新
  static final GlobalKey<_SchedulePageState> globalKey = GlobalKey<_SchedulePageState>();

  // 添加刷新方法
  static void refreshSchedules(BuildContext context) {
    // 使用Provider.of查找_SchedulePageState并调用刷新方法
    print('调用刷新日程方法');
    
    // 尝试通过全局Key刷新
    if (globalKey.currentState != null) {
      print('通过GlobalKey找到SchedulePage状态，强制刷新日程');
      globalKey.currentState!._loadSchedules();
      return;
    }
    
    // 备用方法：使用Provider通知所有监听者
    try {
      // 检查context是否仍然有效
      if (!context.mounted) {
        print('context已经不再挂载，跳过Provider刷新');
        return;
      }
      
      // 使用Provider尝试刷新所有SchedulePage
      final scheduleData = Provider.of<ScheduleData>(context, listen: false);
      scheduleData.notifyListeners();
      print('通过Provider通知刷新成功');
    } catch (e) {
      print('尝试Provider刷新失败: $e');
      // 错误发生时不做任何操作，避免应用崩溃
    }
  }

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDay = DateTime.now();
  DateTime _currentMonth = DateTime.now();

  // 使用 DraggableScrollableController 替代自定义动画控制器
  late final DraggableScrollableController _dragController;

  // 日程服务和数据
  final ScheduleService _scheduleService = ScheduleService();
  final ScheduleDataMigrator _dataMigrator = ScheduleDataMigrator();
  List<ScheduleItem> _scheduleItems = [];
  bool _isLoading = true;
  Map<DateTime, List<ScheduleItem>> _scheduleItemsMap = {};

  // 记录当前活跃的日历本ID，用于检测变化
  String? _currentActiveCalendarId;

  // 暴露给GlobalKey使用
  void reloadSchedules() {
    _loadSchedules();
  }

  @override
  void initState() {
    super.initState();

    // 初始化拖动控制器
    _dragController = DraggableScrollableController();

    // 初始化时迁移测试数据并加载日程数据
    _initData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 检查日历本是否发生变化 - 仅在非加载状态下检查，避免循环
    if (!_isLoading) {
      _checkCalendarBookChanged();
    }
  }

  // 检查日历本是否变化，如果变化则重新加载数据
  void _checkCalendarBookChanged() {
    try {
      final calendarManager = Provider.of<CalendarBookManager>(
        context,
        listen: false,
      );
      final activeCalendarId = calendarManager.activeBook?.id;

      // 如果日历本ID变化，重新加载数据
      if (activeCalendarId != _currentActiveCalendarId) {
        _currentActiveCalendarId = activeCalendarId;
        _loadSchedules();
      }
    } catch (e) {
      print('检查日历本变化时出错: $e');
      // 出错时不阻止应用继续运行
    }
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  // 初始化数据
  Future<void> _initData() async {
    try {
      // 检查并迁移测试数据
      await _dataMigrator.migrateIfNeeded();

      // 初始化时获取当前活跃的日历本ID
      if (mounted) {
        try {
          final calendarManager = Provider.of<CalendarBookManager>(
            context,
            listen: false,
          );
          _currentActiveCalendarId = calendarManager.activeBook?.id;
        } catch (e) {
          print('获取日历本ID时出错: $e');
        }
      }

      // 加载日程数据
      await _loadSchedules();
    } catch (e) {
      print('初始化数据时出错: $e');
      // 确保即使出错也将加载状态设为false
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 加载日程数据
  Future<void> _loadSchedules() async {
    // 确保无论什么情况都重新加载数据
    print('开始加载日程数据');

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      String? activeCalendarId;

      if (mounted) {
        final calendarManager = Provider.of<CalendarBookManager>(
          context,
          listen: false,
        );
        activeCalendarId = calendarManager.activeBook?.id;

        // 更新当前活跃的日历本ID
        _currentActiveCalendarId = activeCalendarId;
      }

      if (activeCalendarId == null) {
        if (mounted) {
          setState(() {
            _scheduleItems = [];
            _scheduleItemsMap = {};
            _isLoading = false;
          });
        }
        return;
      }

      // 获取当前月和前后一个月的日程（为了展示跨月数据）
      final startDate = DateTime(
        _currentMonth.year,
        _currentMonth.month - 1,
        1,
      );
      final endDate = DateTime(_currentMonth.year, _currentMonth.month + 2, 0);

      print('刷新日程: 加载 ${startDate.toString()} 到 ${endDate.toString()} 的数据');
      
      // 从数据库加载日程数据
      final items = await _scheduleService.getSchedulesInRange(
        activeCalendarId,
        startDate,
        endDate,
      );

      print('刷新日程: 加载了 ${items.length} 条日程数据');
      
      // 确保任务完成状态是最新的
      if (mounted) {
        final scheduleData = Provider.of<ScheduleData>(context, listen: false);
        await scheduleData.loadTaskCompletionStatus();
        print('已重新加载任务完成状态数据');
      }

      // 更新界面
      if (mounted) {
        setState(() {
          _scheduleItems = items;
          _scheduleItemsMap = _groupSchedulesByDate(items);
          _isLoading = false;
        });
        print('日历页面数据已更新，日程数量: ${items.length}');
      }
    } catch (e) {
      print('加载日程数据时出错: $e');
      if (mounted) {
        setState(() {
          _scheduleItems = [];
          _scheduleItemsMap = {};
          _isLoading = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载日程失败: $e')));
      }
    }
  }

  // 按日期分组日程数据
  Map<DateTime, List<ScheduleItem>> _groupSchedulesByDate(
    List<ScheduleItem> items,
  ) {
    final groupedMap = <DateTime, List<ScheduleItem>>{};

    for (final item in items) {
      final date = DateTime(
        item.startTime.year,
        item.startTime.month,
        item.startTime.day,
      );

      if (!groupedMap.containsKey(date)) {
        groupedMap[date] = [];
      }

      groupedMap[date]!.add(item);
    }

    return groupedMap;
  }

  // 获取特定日期的日程数量
  int _getScheduleCountForDate(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    return _scheduleItemsMap[dateKey]?.length ?? 0;
  }

  // 获取特定日期的已完成任务数量
  int _getCompletedScheduleCountForDate(DateTime date) {
    if (!mounted) return 0;
    
    try {
      // 使用消费者模式而不是直接访问context
      final scheduleData = Provider.of<ScheduleData>(
        context, 
        listen: false
      );
      return scheduleData.getCompletedTaskCount(date);
    } catch (e) {
      print('获取已完成任务数量出错: $e');
      // 当遇到错误时返回0，而不是继续抛出异常
      return 0;
    }
  }

  // 添加重置面板和日历的方法
  void _resetPanelAndCalendar() {
    if (!mounted) return;

    // 使用微任务确保在下一帧执行动画
    Future.microtask(() {
      // 重置面板到初始状态（30%展开）
      if (_dragController.isAttached) {
        _dragController.animateTo(
          0.3,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸和安全区域
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final statusBarHeight = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    // 添加日历本变化监听器，确保在日历本切换时立即更新数据
    return Consumer<CalendarBookManager>(
      builder: (context, calendarManager, child) {
        // 检查日历本是否变化
        final activeCalendarId = calendarManager.activeBook?.id;
        if (activeCalendarId != _currentActiveCalendarId && !_isLoading) {
          // 使用微任务确保在当前帧渲染完成后执行，避免在build过程中调用setState
          Future.microtask(() {
            _currentActiveCalendarId = activeCalendarId;
            _loadSchedules();
          });
        }

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false, // 让底部面板可以延伸到底部安全区域
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Stack(
                      children: [
                        // 日历网格 - 直接放在 Stack 中，不使用 Expanded
                        CalendarGrid(
                          currentMonth: _currentMonth,
                          selectedDay: _selectedDay,
                          onDateSelected: (date) {
                            setState(() {
                              _selectedDay = date;
                            });
                            
                            // 选择日期后不再自动展开面板，保持默认状态
                            // 注释掉之前的代码
                            // if (_dragController.isAttached) {
                            //   _dragController.animateTo(
                            //     0.6,
                            //     duration: const Duration(milliseconds: 300),
                            //     curve: Curves.easeInOut,
                            //   );
                            // }
                          },
                          onMonthChanged: (month) {
                            setState(() {
                              _currentMonth = month;
                            });
                            _loadSchedules();
                          },
                          scheduleItemsMap: _scheduleItemsMap,
                          getScheduleCountForDate: _getCompletedScheduleCountForDate,
                        ),

                        // 添加测试按钮
                        Positioned(
                          top: 10,
                          right: 10,
                          child: FloatingActionButton(
                            mini: true,
                            backgroundColor: Colors.red,
                            child: const Icon(Icons.sync, color: Colors.white),
                            onPressed: () => _testSyncSpecificTask(),
                          ),
                        ),

                        // 使用 DraggableScrollableSheet 替代自定义面板
                        DraggableScrollableSheet(
                          controller: _dragController,
                          initialChildSize: 0.3, // 初始高度为屏幕的30%
                          minChildSize: 0.3, // 最小高度为屏幕的30%
                          maxChildSize: 0.85, // 最大高度为屏幕的85%（避免全部覆盖日历）
                          snap: true, // 启用吸附效果
                          snapSizes: const [0.3, 0.85], // 定义吸附位置
                          builder: (context, scrollController) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 0,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              // 使用CustomScrollView以支持不同类型的滚动组件
                              child: Column(
                                children: [
                                  // 拖动指示器移到这里，作为容器的第一个子元素
                                  Container(
                                    width: 50,
                                    height: 5,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(2.5),
                                    ),
                                  ),
                                  //标题容器，显示今日行程，明天行程，后天行程
                                  Container(
                                    height: 40,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          mainAxisSize:
                                              MainAxisSize.min, // 最小高度
                                          children: [
                                            // 日期标题
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 15,
                                                    vertical: 0,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        _getDateDescription(
                                                          _selectedDay,
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          color:
                                                              const Color.fromARGB(
                                                                255,
                                                                214,
                                                                74,
                                                                74,
                                                              ),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      // 显示日期
                                                      const SizedBox(width: 10),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.calendar_today,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      // 显示今日行程，明天行程，后天行程
                                                      Text(
                                                        '${_selectedDay.year}年${_selectedDay.month}月${_selectedDay.day}日',
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const Divider(height: 1),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 剩余内容使用Expanded包裹，确保填满剩余空间
                                  Expanded(
                                    child: CustomScrollView(
                                      controller: scrollController,
                                      slivers: [
                                        SliverToBoxAdapter(),

                                        // 检查是否有日程，显示对应内容
                                        _buildScheduleListSliver(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
          ),
        );
      },
    );
  }

  // 构建日程列表 Sliver
  Widget _buildScheduleListSliver() {
    final dateKey = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );

    // 获取当前日期的日程列表
    final schedules = _scheduleItemsMap[dateKey] ?? [];

    if (schedules.isEmpty) {
      // 使用 SliverFillRemaining 确保空状态填满剩余空间
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_note, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                '暂无日程',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '点击顶部"+"按钮添加新日程',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // 有日程内容，展示日程列表
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final schedule = schedules[index];
          return ui.ScheduleItemWidget(
            item: schedule,
            onToggleComplete: () {
              _toggleTaskComplete(schedule);
            },
          );
        }, childCount: schedules.length),
      ),
    );
  }

  // 打开添加新日程的对话框
  void _showAddScheduleDialog() {
    final calendarManager = Provider.of<CalendarBookManager>(
      context,
      listen: false,
    );
    final activeCalendarId = calendarManager.activeBook?.id;

    if (activeCalendarId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择或创建一个日历本')));
      return;
    }

    // 创建临时的日程项，稍后进行编辑和保存
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return AddScheduleSheet(
          selectedDate: _selectedDay,
          calendarId: activeCalendarId,
          onScheduleAdded: (ScheduleItem newSchedule) {
            _loadSchedules();
          },
        );
      },
    );
  }

  // 显示日程操作选项
  void _showScheduleOptions(ScheduleItem schedule) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('编辑日程'),
                onTap: () {
                  Navigator.pop(context);
                  _editSchedule(schedule);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除日程', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteSchedule(schedule);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 编辑日程
  void _editSchedule(ScheduleItem schedule) {
    // 实现编辑日程的逻辑
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return EditScheduleSheet(
          schedule: schedule,
          onScheduleUpdated: (ScheduleItem updatedSchedule) {
            _loadSchedules();
          },
        );
      },
    );
  }

  // 删除日程
  void _deleteSchedule(ScheduleItem schedule) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定要删除这个日程吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmDeleteSchedule(schedule);
              },
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // 确认删除日程
  Future<void> _confirmDeleteSchedule(ScheduleItem schedule) async {
    try {
      // 获取日历管理器，用于获取分享码
      final calendarManager = Provider.of<CalendarBookManager>(context, listen: false);
      final shareCode = calendarManager.getShareId(schedule.calendarId);
      
      // 调用服务删除日程
      final scheduleService = ScheduleService();
      await scheduleService.deleteSchedule(schedule.id);

      // 刷新日程列表
      _loadSchedules();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日程已删除')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  // 显示面板（带动画）
  void _expandPanel() {
    if (_dragController.isAttached) {
      _dragController.animateTo(
        0.85,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // 收起面板（带动画）
  void _collapsePanel() {
    if (_dragController.isAttached) {
      _dragController.animateTo(
        0.3,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // 处理日期选择
  void _handleDateSelected(DateTime date) {
    setState(() {
      // 如果点击的是已选中的日期，切换面板展开/收起状态
      if (_selectedDay.year == date.year &&
          _selectedDay.month == date.month &&
          _selectedDay.day == date.day) {
        if (_dragController.isAttached) {
          final currentSize = _dragController.size;
          if (currentSize > 0.6) {
            _collapsePanel();
          } else {
            _expandPanel();
          }
        }
      } else {
        // 选择了新日期，展开面板
        _selectedDay = date;
        // _expandPanel();
      }
    });
  }

  // 修改月份切换处理方法
  void _handleMonthChanged(DateTime newMonth) {
    // 月份切换时重置面板和日历
    _resetPanelAndCalendar();

    setState(() {
      _currentMonth = newMonth;

      // 如果切换到当前月份，选中今天
      if (newMonth.year == DateTime.now().year &&
          newMonth.month == DateTime.now().month) {
        _selectedDay = DateTime.now();
      } else {
        // 尝试保持用户在上个月选择的相同日期
        // 检查新月份中是否有对应的日期（避免例如选择了31日但下个月没有31日的情况）
        final daysInNewMonth =
            DateTime(newMonth.year, newMonth.month + 1, 0).day;
        if (_selectedDay.day <= daysInNewMonth) {
          // 保持相同日期，只更新月份和年份
          _selectedDay = DateTime(
            newMonth.year,
            newMonth.month,
            _selectedDay.day,
          );
        } else {
          // 如果新月份没有对应的日期（例如从3月31日到4月），选择新月份的最后一天
          _selectedDay = DateTime(
            newMonth.year,
            newMonth.month,
            daysInNewMonth,
          );
        }
      }
    });

    _loadSchedules();
  }

  // 添加获取相对日期描述的方法
  String _getDateDescription(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(date.year, date.month, date.day);
    final difference = selectedDate.difference(today).inDays;

    switch (difference) {
      case 0:
        return '今天行程';
      case 1:
        return '明天行程';
      case 2:
        return '后天行程';
      default:
        return '';
    }
  }

  // 切换任务完成状态
  void _toggleTaskComplete(ScheduleItem schedule) {
    // 使用统一的任务完成状态服务
    TaskCompletionService.toggleTaskCompletion(
      context, 
      schedule,
      onStateChanged: () {
        // 刷新UI以显示更新后的状态
        setState(() {});
      }
    );
  }
  
  // 新增方法：更新数据库中任务的完成状态
  // 此方法已移至 TaskCompletionService，保留此方法仅为兼容性考虑
  Future<void> _updateScheduleCompletionInDatabase(ScheduleItem schedule, bool isCompleted) async {
    try {
      // 创建包含新完成状态的日程对象
      final updatedSchedule = schedule.copyWith(isCompleted: isCompleted);
      
      // 使用ScheduleService更新数据库
      final scheduleService = ScheduleService();
      await scheduleService.updateSchedule(updatedSchedule);
      
      print('成功更新任务完成状态到数据库：${schedule.title}, 完成状态: $isCompleted');
    } catch (e) {
      print('更新任务完成状态到数据库时出错: $e');
      // 不抛出异常，避免影响用户体验
    }
  }

  // 测试同步指定任务
  void _testSyncSpecificTask() async {
    // 获取日历管理器实例
    final calendarManager = Provider.of<CalendarBookManager>(context, listen: false);
    
    try {
      // 显示加载指示器
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在同步指定任务...')
            ],
          ),
        ),
      );
      
      // 指定任务ID和分享码
      final String scheduleId = 'ccc39192-c5c4-4830-9699-42fa09e648fc';
      final String shareCode = 'ccbee1b02452';
      
      // 将任务设置为未完成
      final result = await calendarManager.syncSpecificTask(shareCode, scheduleId, false);
      
      // 关闭加载对话框
      if (mounted) Navigator.of(context).pop();
      
      print('同步结果: $result');
      
      // 提示同步结果
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('任务同步结果: ${result ? "成功" : "失败"}'),
            duration: const Duration(seconds: 3),
          ),
        );
        
        // 如果同步成功，刷新日程列表
        if (result) {
          _loadSchedules();
        }
      }
    } catch (e) {
      // 关闭加载对话框
      if (mounted) Navigator.of(context).pop();
      
      print('测试同步时出错: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('同步错误: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
