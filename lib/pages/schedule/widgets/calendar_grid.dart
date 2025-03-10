import 'package:flutter/material.dart';
import '../../../models/schedule_item.dart';

class CalendarGrid extends StatefulWidget {
  final DateTime currentMonth;
  final DateTime selectedDay;
  final Function(DateTime) onDateSelected;
  final Function(DateTime) onMonthChanged;
  final Map<DateTime, List<ScheduleItem>> scheduleItemsMap;
  final int Function(DateTime) getScheduleCountForDate;

  const CalendarGrid({
    Key? key,
    required this.currentMonth,
    required this.selectedDay,
    required this.onDateSelected,
    required this.onMonthChanged,
    required this.scheduleItemsMap,
    required this.getScheduleCountForDate,
  }) : super(key: key);

  @override
  State<CalendarGrid> createState() => _CalendarGridState();
}

class _CalendarGridState extends State<CalendarGrid> {
  @override
  void didUpdateWidget(CalendarGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 如果scheduleItemsMap发生变化，强制刷新
    if (widget.scheduleItemsMap != oldWidget.scheduleItemsMap) {
      print('日历网格检测到scheduleItemsMap变化，强制刷新');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取当月第一天是周几（0是周日，1是周一）
    final firstDayWeekday = DateTime(widget.currentMonth.year, widget.currentMonth.month, 1).weekday;
    // 获取上个月的天数
    final lastMonthDays = DateTime(widget.currentMonth.year, widget.currentMonth.month, 0).day;
    // 计算需要显示的上个月的天数
    final previousMonthDays = (firstDayWeekday + 6) % 7;
    
    // 获取这个月的所有日期
    final daysInMonth = _getDaysInMonth(widget.currentMonth);
    
    // 创建日历网格的所有日期（包括上个月和下个月的日期）
    final allDays = <DateTime>[];
    
    // 添加上个月的日期
    for (var i = previousMonthDays - 1; i >= 0; i--) {
      allDays.add(
        DateTime(widget.currentMonth.year, widget.currentMonth.month - 1, lastMonthDays - i),
      );
    }
    
    // 添加当月的日期
    allDays.addAll(daysInMonth);
    
    // 添加下个月的日期（补齐42个格子）
    final remainingDays = 42 - allDays.length;
    for (var i = 1; i <= remainingDays; i++) {
      allDays.add(
        DateTime(widget.currentMonth.year, widget.currentMonth.month + 1, i),
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  widget.onMonthChanged(
                    DateTime(widget.currentMonth.year, widget.currentMonth.month - 1),
                  );
                },
                icon: const Icon(Icons.chevron_left),
              ),// 添加月历切换按钮
              Text(
                '${widget.currentMonth.year}年${widget.currentMonth.month}月',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),// 添加月历切换按钮
              IconButton(
                onPressed: () {
                  widget.onMonthChanged(
                    DateTime(widget.currentMonth.year, widget.currentMonth.month + 1),
                  );
                },
                icon: const Icon(Icons.chevron_right),
              ),// 添加月历切换按钮
            ],
          ),
        ),
        Row(
          children: const [
            _WeekdayHeader('一'),
            _WeekdayHeader('二'),
            _WeekdayHeader('三'),
            _WeekdayHeader('四'),
            _WeekdayHeader('五'),
            _WeekdayHeader('六'),
            _WeekdayHeader('日'),
          ],
        ),
        Expanded(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8), // 添加整体内边距
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              crossAxisSpacing: 4, // 添加横向间距
              mainAxisSpacing: 4,  // 添加纵向间距
            ),
            itemCount: allDays.length,
            itemBuilder: (context, index) {
              final day = allDays[index];
              final isCurrentMonth = day.month == widget.currentMonth.month;
              final isSelected = day.year == widget.selectedDay.year &&
                  day.month == widget.selectedDay.month &&
                  day.day == widget.selectedDay.day;
              final isToday = day.year == DateTime.now().year &&
                  day.month == DateTime.now().month &&
                  day.day == DateTime.now().day;
              
              return _buildDayCell(context, day, isSelected, isCurrentMonth, isToday);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime day, bool isSelected, bool isCurrentMonth, bool isToday) {
    final daySchedules = widget.scheduleItemsMap[day] ?? [];
    
    // 获取总任务数量
    final totalCount = daySchedules.length;
    
    // 使用回调函数获取已完成的任务数量
    final completedCount = widget.getScheduleCountForDate(day);
    
    // 计算未完成的任务数量
    final uncompletedCount = totalCount - completedCount;
    
    return InkWell(
      onTap: () => widget.onDateSelected(day),
      child: Container(
        decoration: BoxDecoration(
          color: isToday 
            ? Theme.of(context).colorScheme.primary
            : isSelected 
              ? Theme.of(context).colorScheme.primary.withAlpha(26)
              : null,
          border: !isToday ? Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ) : null,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected || isToday ? [
            BoxShadow(
              color: Colors.black.withAlpha(isToday ? 20 : 15),
              blurRadius: 4,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              day.day.toString(),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ).copyWith(
                color: !isCurrentMonth
                  ? Colors.grey[400]
                  : isToday
                    ? Colors.white
                    : isSelected 
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black87,
                fontWeight: isSelected || isToday 
                  ? FontWeight.bold 
                  : FontWeight.normal,
              ),
            ),
            if (totalCount > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (completedCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isToday 
                          ? Colors.white.withAlpha(230)
                          : !isCurrentMonth 
                            ? Colors.green[100]?.withAlpha(179)
                            : Colors.green[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        completedCount.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ).copyWith(
                          color: isToday
                            ? Colors.green[700]
                            : !isCurrentMonth
                              ? Colors.green[700]?.withAlpha(179)
                              : Colors.green[700],
                        ),
                      ),
                    ),
                  if (completedCount > 0 && uncompletedCount > 0)
                    const SizedBox(width: 4),
                  if (uncompletedCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isToday
                          ? Colors.white.withAlpha(230)
                          : !isCurrentMonth
                            ? Colors.red[100]?.withAlpha(179)
                            : Colors.red[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        uncompletedCount.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ).copyWith(
                          color: isToday
                            ? Colors.red[700]
                            : !isCurrentMonth
                              ? Colors.red[700]?.withAlpha(179)
                              : Colors.red[700],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  List<DateTime> _getDaysInMonth(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0);
    return List.generate(
      lastDay.day,
      (index) => DateTime(month.year, month.month, index + 1),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String text;

  const _WeekdayHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 40,
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
} 