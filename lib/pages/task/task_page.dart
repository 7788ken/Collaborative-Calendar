import 'package:flutter/material.dart';
import '../../data/schedule_data.dart';
import '../../data/models/schedule_item.dart';
import 'widgets/task_item.dart';

class TaskPage extends StatelessWidget {
  const TaskPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TaskView();
  }
}

class TaskView extends StatefulWidget {
  const TaskView({super.key});

  @override
  State<TaskView> createState() => _TaskViewState();
}

class _TaskViewState extends State<TaskView> {
  final List<ScheduleItem> _scheduleItems = ScheduleData.scheduleItems;

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

  String _getWeekday(int weekday) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[weekday - 1];
  }

  void _deleteSchedule(ScheduleItem item) {
    setState(() {
      _scheduleItems.remove(item);
    });
  }

  void _toggleComplete(ScheduleItem item) {
    setState(() {
      item.isCompleted = !item.isCompleted;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          ],
        ),
      );
    }

    return ListView.builder(
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
            )).toList(),
            // 分隔线
            if (index < groupedSchedules.length - 1)
              const Divider(height: 32),
          ],
        );
      },
    );
  }
} 