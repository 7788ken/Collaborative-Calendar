import 'package:flutter/material.dart';
import '../../../models/schedule_item.dart';
import '../../../data/schedule_service.dart';

class EditScheduleSheet extends StatefulWidget {
  final ScheduleItem schedule;
  final Function(ScheduleItem) onScheduleUpdated;

  const EditScheduleSheet({
    super.key, 
    required this.schedule, 
    required this.onScheduleUpdated,
  });

  @override
  State<EditScheduleSheet> createState() => _EditScheduleSheetState();
}

class _EditScheduleSheetState extends State<EditScheduleSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _isAllDay;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.schedule.title);
    _descriptionController = TextEditingController(text: widget.schedule.description ?? '');
    _locationController = TextEditingController(text: widget.schedule.location ?? '');
    _startTime = TimeOfDay(hour: widget.schedule.startTime.hour, minute: widget.schedule.startTime.minute);
    _endTime = TimeOfDay(hour: widget.schedule.endTime.hour, minute: widget.schedule.endTime.minute);
    _isAllDay = widget.schedule.isAllDay;
  }

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
                  '编辑日程',
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
                onPressed: _updateSchedule,
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

  void _updateSchedule() {
    if (_formKey.currentState!.validate()) {
      // 创建开始和结束日期时间
      final startDateTime = DateTime(
        widget.schedule.startTime.year,
        widget.schedule.startTime.month,
        widget.schedule.startTime.day,
        _isAllDay ? 0 : _startTime.hour,
        _isAllDay ? 0 : _startTime.minute,
      );
      
      final endDateTime = _isAllDay 
          ? DateTime(
              widget.schedule.endTime.year,
              widget.schedule.endTime.month,
              widget.schedule.endTime.day,
              23,
              59,
            )
          : DateTime(
              widget.schedule.endTime.year,
              widget.schedule.endTime.month,
              widget.schedule.endTime.day,
              _endTime.hour,
              _endTime.minute,
            );
      
      // 创建更新的日程对象
      final updatedSchedule = ScheduleItem(
        id: widget.schedule.id,
        calendarId: widget.schedule.calendarId,
        title: _titleController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        location: _locationController.text.isEmpty ? null : _locationController.text,
        startTime: startDateTime,
        endTime: endDateTime,
        isAllDay: _isAllDay,
        createdAt: widget.schedule.createdAt,
      );
      
      // 保存到数据库
      _saveToDatabase(updatedSchedule);
    }
  }

  Future<void> _saveToDatabase(ScheduleItem schedule) async {
    try {
      // 更新数据库
      final scheduleService = ScheduleService();
      await scheduleService.updateSchedule(schedule);
      
      // 回调通知父组件
      widget.onScheduleUpdated(schedule);
      
      // 关闭底部表单
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日程已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }
} 