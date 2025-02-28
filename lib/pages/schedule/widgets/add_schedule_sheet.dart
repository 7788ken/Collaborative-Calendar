import 'package:flutter/material.dart';
import '../../../models/schedule_item.dart';
import '../../../data/schedule_service.dart';
import '../../../data/calendar_book_manager.dart';
import 'package:provider/provider.dart';

class AddScheduleSheet extends StatefulWidget {
  final DateTime selectedDate;
  final String calendarId;
  final Function(ScheduleItem) onScheduleAdded;

  const AddScheduleSheet({
    super.key, 
    required this.selectedDate, 
    required this.calendarId,
    required this.onScheduleAdded,
  });

  @override
  State<AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<AddScheduleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  TimeOfDay _startTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 10, minute: 0);
  bool _isAllDay = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '添加日程',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入日程标题';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _isAllDay,
                  onChanged: (value) {
                    setState(() {
                      _isAllDay = value ?? false;
                    });
                  },
                ),
                const Text('全天'),
              ],
            ),
            if (!_isAllDay) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectStartTime(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '开始时间',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectEndTime(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '结束时间',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '地点',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '备注',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSchedule,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('保存'),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
        // 如果开始时间晚于结束时间，调整结束时间
        if (_startTime.hour > _endTime.hour || 
            (_startTime.hour == _endTime.hour && _startTime.minute >= _endTime.minute)) {
          _endTime = TimeOfDay(
            hour: _startTime.hour + 1,
            minute: _startTime.minute,
          );
        }
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null && picked != _endTime) {
      setState(() {
        _endTime = picked;
        // 如果结束时间早于开始时间，调整开始时间
        if (_endTime.hour < _startTime.hour || 
            (_endTime.hour == _startTime.hour && _endTime.minute <= _startTime.minute)) {
          _startTime = TimeOfDay(
            hour: _endTime.hour - 1,
            minute: _endTime.minute,
          );
        }
      });
    }
  }

  void _saveSchedule() {
    if (_formKey.currentState!.validate()) {
      // 创建开始和结束日期时间
      final startDateTime = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        _isAllDay ? 0 : _startTime.hour,
        _isAllDay ? 0 : _startTime.minute,
      );
      
      final endDateTime = _isAllDay 
          ? DateTime(
              widget.selectedDate.year,
              widget.selectedDate.month,
              widget.selectedDate.day,
              23,
              59,
            )
          : DateTime(
              widget.selectedDate.year,
              widget.selectedDate.month,
              widget.selectedDate.day,
              _endTime.hour,
              _endTime.minute,
            );
      
      // 创建日程对象
      final schedule = ScheduleItem(
        calendarId: widget.calendarId,
        title: _titleController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        location: _locationController.text.isEmpty ? null : _locationController.text,
        startTime: startDateTime,
        endTime: endDateTime,
        isAllDay: _isAllDay,
      );
      
      // 保存到数据库
      _saveToDatabase(schedule);
    }
  }

  Future<void> _saveToDatabase(ScheduleItem schedule) async {
    try {
      // 保存到数据库
      final scheduleService = ScheduleService();
      await scheduleService.addSchedule(schedule);
      
      // 回调通知父组件
      widget.onScheduleAdded(schedule);
      
      // 判断是否需要同步到云端
      final calendarManager = Provider.of<CalendarBookManager>(context, listen: false);
      try {
        final calendarBook = calendarManager.books.firstWhere(
          (book) => book.id == schedule.calendarId,
          orElse: () => throw Exception('找不到日历本'),
        );
        
        // 如果是共享日历，则同步到云端 - 只同步当前新增的日程
        if (calendarBook.isShared) {
          print('新增日程：检测到共享日历的日程变更，准备同步到云端...');
          print('同步单条日程，ID: ${schedule.id}');
          Future.microtask(() async {
            try {
              // 只同步特定的日程ID，而不是整个日历的所有日程
              await calendarManager.syncSharedCalendarSchedules(
                schedule.calendarId,
                specificScheduleId: schedule.id
              );
              print('新增日程：云端同步完成');
            } catch (e) {
              print('新增日程：同步到云端时出错: $e');
              // 但不显示错误，避免影响用户体验
            }
          });
        }
      } catch (e) {
        print('获取日历本信息时出错: $e');
      }
      
      // 关闭底部表单
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日程已添加')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }
} 