import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/schedule_item.dart';
import '../../../data/schedule_data.dart';
import 'package:provider/provider.dart';

class ScheduleItemWidget extends StatelessWidget {
  final ScheduleItem item;
  final VoidCallback onToggleComplete;

  const ScheduleItemWidget({
    super.key,
    required this.item,
    required this.onToggleComplete,
  });

  // 格式化时间为小时:分钟格式
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // 获取任务完成状态
    final scheduleData = Provider.of<ScheduleData>(context);
    // 使用正确的方法名和任务键格式
    final taskKey = "${item.startTime.year}-${item.startTime.month}-${item.startTime.day}-${item.id}";
    final isCompleted = scheduleData.getTaskCompletionStatus(taskKey);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.grey.shade100 : Colors.white,
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
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isCompleted 
                    ? Colors.green.withAlpha(30)
                    : Theme.of(context).colorScheme.primary.withAlpha(20),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatTime(item.startTime),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: Colors.grey,
                  ),
                  Text(
                    _formatTime(item.endTime),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted ? Colors.grey : Colors.black87,
                      ),
                    ),
                    if (item.location != null && item.location!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: const Color.fromARGB(255, 184, 61, 61),
                          ),
                          SizedBox(
                            width: 4,
                          ),
                          Text(
                            item.location!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.my_library_books_rounded,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          SizedBox(
                            width: 4,
                          ),
                          Text(
                            item.description!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // 完成按钮
            IconButton(
              icon: isCompleted 
                  ? const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    )
                  : Icon(
                      Icons.check_circle_outline,
                      color: Colors.grey[400],
                    ),
              onPressed: () {
                // 添加振动反馈
                HapticFeedback.lightImpact();
                onToggleComplete();
              },
              tooltip: isCompleted ? '标记为未完成' : '标记为已完成',
            ),
          ],
        ),
      ),
    );
  }
} 