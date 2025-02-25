import 'package:flutter/material.dart';
import '../../../data/models/schedule_item.dart';
import '../../../widgets/add_schedule_page.dart';

class TaskItemWidget extends StatelessWidget {
  final ScheduleItem item;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;

  const TaskItemWidget({
    super.key,
    required this.item,
    required this.onToggleComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(20),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // 时间指示器
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(20),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.startTime,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: Colors.grey,
                  ),
                  Text(
                    item.endTime,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // 内容区域
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (item.location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '📍 ${item.location}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (item.remark.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.remark,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // 操作按钮
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    item.isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                    color: item.isCompleted ? Colors.green : Colors.grey[400],
                  ),
                  onPressed: onToggleComplete,
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddSchedulePage(scheduleItem: item),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red[300],
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 