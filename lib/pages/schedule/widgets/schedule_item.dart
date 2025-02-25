import 'package:flutter/material.dart';
import '../../../data/models/schedule_item.dart';

class ScheduleItemWidget extends StatelessWidget {
  final ScheduleItem item;
  final VoidCallback onToggleComplete;

  const ScheduleItemWidget({
    super.key,
    required this.item,
    required this.onToggleComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTimeAxis(),
          _buildContent(),
          IconButton(
            onPressed: onToggleComplete,
            icon: Icon(
              item.isCompleted ? Icons.check_circle : Icons.check_circle_outline,
              color: item.isCompleted ? Colors.green : Colors.grey,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeAxis() {
    return Container(
      width: 80,
      padding: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Colors.grey.withAlpha(51),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.time.split(' - ')[0],
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Icon(
            Icons.arrow_downward,
            size: 14,
            color: Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            item.time.split(' - ')[1],
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  item.location,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (item.remark.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.notes,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.remark,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
} 