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

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

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
    // 如果已经在加载中，避免重复加载
    // 但初始加载时(_isLoading初始为true)不应该跳过
    if (_isLoading && _scheduleItems.isNotEmpty) return;

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

      // 从数据库加载日程数据
      final items = await _scheduleService.getSchedulesInRange(
        activeCalendarId,
        startDate,
        endDate,
      );

      if (mounted) {
        setState(() {
          _scheduleItems = items;
          _scheduleItemsMap = _groupSchedulesByDate(items);
          _isLoading = false;
        });
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
                        // 日历网格
                        SizedBox(
                          height: screenHeight,
                          child: CalendarGrid(
                            currentMonth: _currentMonth,
                            selectedDay: _selectedDay,
                            onDateSelected: _handleDateSelected,
                            onMonthChanged: _handleMonthChanged,
                            scheduleItemsMap: _scheduleItemsMap,
                            getScheduleCountForDate: _getScheduleCountForDate,
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
              _showScheduleOptions(schedule);
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
      final scheduleService = ScheduleService();
      await scheduleService.deleteSchedule(schedule.id);

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
}
