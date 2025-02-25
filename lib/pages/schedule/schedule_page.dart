import 'package:flutter/material.dart';
import '../../data/schedule_data.dart';
import '../../data/models/schedule_item.dart';
import 'widgets/calendar_grid.dart';
import 'widgets/schedule_item.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime _selectedDay = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  double _calendarHeight = 520.0;
  late final DraggableScrollableController _dragController;
  
  // 添加日程数据
  final List<ScheduleItem> _scheduleItems = ScheduleData.scheduleItems;

  @override
  void initState() {
    super.initState();
    _dragController = DraggableScrollableController();
  }

  // 添加重置面板和日历的方法
  void _resetPanelAndCalendar() {
    if (!mounted) return;
    
    setState(() {
      _calendarHeight = 520.0;
    });

    Future.microtask(() {
      if (_dragController.isAttached) {
        _dragController.animateTo(
          0.3,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // 添加日程分组方法
  Map<DateTime, List<ScheduleItem>> _groupSchedulesByDate(List<ScheduleItem> items) {
    final grouped = <DateTime, List<ScheduleItem>>{};
    
    for (var item in items) {
      final date = DateTime(item.date.year, item.date.month, item.date.day);
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(item);
    }
    
    return Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key))
    );
  }

  // 修改月份切换处理方法
  void _handleMonthChanged(DateTime newMonth) {
    setState(() {
      _currentMonth = newMonth;
      // 如果切换到当前月份，选中今天
      if (newMonth.year == DateTime.now().year && 
          newMonth.month == DateTime.now().month) {
        _selectedDay = DateTime.now();
      } else {
        // 否则选中该月1号
        _selectedDay = DateTime(newMonth.year, newMonth.month, 1);
      }
      // 重置面板
      _resetPanelAndCalendar();
    });
  }

  // 添加获取相对日期描述的方法
  String _getDateDescription(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(date.year, date.month, date.day);
    final difference = selectedDate.difference(today).inDays;

    switch (difference) {
      case 0:
        return '今日行程';
      case 1:
        return '明天行程';
      case 2:
        return '后天行程';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SizedBox(
            height: _calendarHeight,
            child: CalendarGrid(
              currentMonth: _currentMonth,
              selectedDay: _selectedDay,
              onDaySelected: (date) {
                setState(() {
                  _selectedDay = date;
                  _resetPanelAndCalendar();
                });
              },
              onMonthChanged: _handleMonthChanged,
              schedules: _groupSchedulesByDate(_scheduleItems),
            ),
          ),
          DraggableScrollableSheet(
            controller: _dragController,
            initialChildSize: 0.3,
            minChildSize: 0.1,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              final selectedDateSchedules = _scheduleItems.where((item) =>
                item.date.year == _selectedDay.year &&
                item.date.month == _selectedDay.month &&
                item.date.day == _selectedDay.day
              ).toList();

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 拖动指示器
                            Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            // 日期标题
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: Row(
                                children: [
                                  // 使用 Builder 来构建相对日期标题
                                  Builder(
                                    builder: (context) {
                                      final dateDesc = _getDateDescription(_selectedDay);
                                      if (dateDesc.isEmpty) return const SizedBox.shrink();
                                      
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            dateDesc,
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Theme.of(context).colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 1,
                                            height: 16,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                      );
                                    },
                                  ),
                                  Text(
                                    '${_selectedDay.month}月${_selectedDay.day}日',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${selectedDateSchedules.length}个日程',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                        ),
                      ),
                      // 日程列表
                      selectedDateSchedules.isEmpty
                          ? SliverFillRemaining(
                              child: Center(
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
                                  ],
                                ),
                              ),
                            )
                          : SliverPadding(
                              padding: const EdgeInsets.all(16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final item = selectedDateSchedules[index];
                                    return ScheduleItemWidget(
                                      item: item,
                                      onToggleComplete: () {
                                        setState(() {
                                          item.isCompleted = !item.isCompleted;
                                        });
                                      },
                                    );
                                  },
                                  childCount: selectedDateSchedules.length,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
} 