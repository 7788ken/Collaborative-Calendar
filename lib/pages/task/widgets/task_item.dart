import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/schedule_item.dart';
import '../../../widgets/add_schedule_page.dart';
import '../../../models/schedule_item.dart' as calendar_models;
import '../../../data/calendar_book_manager.dart';
import '../../../data/schedule_service.dart';

class TaskItemWidget extends StatefulWidget {
  final ScheduleItem item;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;
  final Function(calendar_models.ScheduleItem) onEdit;
  final String originalId;
  final bool isUnsynced;
  final VoidCallback onSyncStatusChanged;

  const TaskItemWidget({
    super.key,
    required this.item,
    required this.onToggleComplete,
    required this.onDelete,
    required this.onEdit,
    required this.originalId,
    required this.onSyncStatusChanged,
    this.isUnsynced = false,
  });

  @override
  State<TaskItemWidget> createState() => _TaskItemWidgetState();
}

class _TaskItemWidgetState extends State<TaskItemWidget> with SingleTickerProviderStateMixin {
  // 操作按钮区域宽度
  static const double actionsWidth = 160.0;
  
  // 控制滑动状态
  bool _isOpen = false;
  
  // 动画控制器
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    // 初始化动画控制器
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // 不再在这里初始化滑动动画，移到didChangeDependencies中
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 在这里安全地使用MediaQuery
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(-actionsWidth / MediaQuery.of(context).size.width, 0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  // 切换滑动状态
  void _toggleSlide() {
    if (_isOpen) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() {
      _isOpen = !_isOpen;
    });
  }
  
  // 关闭滑动菜单
  void _closeSlide() {
    if (_isOpen) {
      _controller.reverse();
      setState(() {
        _isOpen = false;
      });
    }
  }
  
  // 新增：处理滑动吸附效果
  void _handleSlideEnd() {
    // 如果滑动进度超过50%，则打开菜单，否则关闭
    if (_controller.value > 0.5) {
      _controller.forward();
      setState(() {
        _isOpen = true;
      });
    } else {
      _controller.reverse();
      setState(() {
        _isOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 计算所需高度，防止完成状态切换时的抖动
    final double itemHeight = 
        widget.item.isCompleted ? 65 : 
        (widget.item.location.isNotEmpty || widget.item.remark.isNotEmpty) ? 
          (widget.item.location.isNotEmpty && widget.item.remark.isNotEmpty ? 110 : 85) : 65;
    
    // 获取时间指示器的宽度
    final double timeIndicatorWidth = !widget.item.isCompleted ? 60 : 50;
    
    return Container(
      height: itemHeight,
      margin: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          // 底层背景 - 包含按钮区域
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 编辑按钮
                    GestureDetector(
                      onTap: () {
                        _closeSlide();
                        // 添加当前活动日历本ID
                        final calendarManager = CalendarBookManager();  // 获取日历管理器实例
                        final activeCalendarId = calendarManager.activeBook?.id ?? 'default';
                        print('编辑任务，使用当前活动日历本ID: $activeCalendarId');
                        widget.onEdit(widget.item.toCalendarSchedule(
                          id: widget.originalId,
                          calendarId: activeCalendarId,  // 使用当前活动日历本ID
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 删除按钮
                    GestureDetector(
                      onTap: () {
                        _closeSlide();
                        widget.onDelete();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 使用Draggable替代手势检测
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: Stack(
              children: [
                // 滑动内容容器
                SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.item.isCompleted ? Colors.grey.shade100 : Colors.white,
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
                    child: Stack(
                      children: [
                        Padding(
                          // 添加左边距为时间指示器宽度，避免重叠
                          padding: EdgeInsets.only(left: timeIndicatorWidth),
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.item.isCompleted ? Colors.grey.shade100 : Colors.white,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                // 内容区域
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_isOpen) {
                                        _toggleSlide();
                                      } else {
                                        widget.onToggleComplete();
                                      }
                                    },
                                    onHorizontalDragEnd: (details) {
                                      // 检测滑动结束时的速度
                                      if (details.primaryVelocity != null) {
                                        if (details.primaryVelocity! < -200) {
                                          // 快速向左滑动 - 打开
                                          if (!_isOpen) _toggleSlide();
                                        } else if (details.primaryVelocity! > 200) {
                                          // 快速向右滑动 - 关闭
                                          if (_isOpen) _toggleSlide();
                                        } else {
                                          // 速度不够，根据位置决定是否吸附
                                          _handleSlideEnd();
                                        }
                                      } else {
                                        // 没有速度信息，根据位置决定是否吸附
                                        _handleSlideEnd();
                                      }
                                    },
                                    onHorizontalDragUpdate: (details) {
                                      // 计算滑动进度，基于滑动距离
                                      final delta = details.primaryDelta;
                                      if (delta == null) return;
                                      
                                      // 向左滑动（负值）处理
                                      if (delta < 0 && !_isOpen) {
                                        final newValue = _controller.value - (delta.abs() / actionsWidth);
                                        _controller.value = newValue.clamp(0.0, 1.0);
                                      } 
                                      // 向右滑动（正值）处理
                                      else if (delta > 0 && _isOpen) {
                                        final newValue = _controller.value - (delta / actionsWidth);
                                        _controller.value = newValue.clamp(0.0, 1.0);
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: widget.item.isCompleted ? Colors.grey.shade100 : Colors.white,
                                        borderRadius: const BorderRadius.horizontal(
                                          right: Radius.circular(12),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  // 删除空白容器
                                                  Text(
                                                    widget.item.title,
                                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                      decoration: widget.item.isCompleted ? TextDecoration.lineThrough : null,
                                                      color: widget.item.isCompleted ? Colors.grey : Colors.black87,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  // 未完成状态显示详细信息
                                                  if (!widget.item.isCompleted) ...[
                                                    if (widget.item.location.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '📍 ${widget.item.location}',
                                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                          color: Colors.grey[600],
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                    if (widget.item.remark.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        widget.item.remark,
                                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                          color: Colors.grey[600],
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                          
                                          // 完成状态切换按钮
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            child: IconButton(
                                              icon: widget.item.isCompleted 
                                                  ? const Icon(
                                                      Icons.refresh_rounded,
                                                      color: Colors.grey,
                                                    )
                                                  : Icon(
                                                      Icons.check_circle_outline,
                                                      color: Colors.grey[400],
                                                    ),
                                              onPressed: () {
                                                // 添加振动反馈
                                                HapticFeedback.lightImpact();
                                                widget.onToggleComplete();
                                              },
                                              tooltip: widget.item.isCompleted ? '标记为未完成' : '标记为已完成',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // 添加未同步状态角标
                        if (widget.isUnsynced)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () async {
                                // 获取 ScheduleService 实例
                                final scheduleService = ScheduleService();
                                
                                // 显示同步中的加载指示器
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('正在同步...'),
                                      ],
                                    ),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                                
                                // 尝试同步
                                final success = await scheduleService.syncSchedule(widget.originalId);
                                
                                if (context.mounted) {
                                  if (success) {
                                    // 同步成功
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('同步成功'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    // 调用刷新回调
                                    widget.onSyncStatusChanged();
                                  } else {
                                    // 同步失败
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('同步失败，请检查网络连接'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error,
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.sync_problem,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 时间指示器层放在最上层，确保不被内容遮挡
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: timeIndicatorWidth,
              decoration: BoxDecoration(
                color: widget.item.isCompleted 
                    ? Colors.green.withAlpha(30)
                    : Theme.of(context).colorScheme.primary.withAlpha(20),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                // 添加小阴影，增强层级感
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(10),
                    blurRadius: 2,
                    spreadRadius: 0,
                    offset: const Offset(1, 0),
                  ),
                ],
              ),
              child: widget.item.isCompleted
                  ? const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.item.startTime,
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
                          widget.item.endTime,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
} 