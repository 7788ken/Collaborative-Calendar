import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/schedule_item.dart';
import '../data/calendar_book_manager.dart';
import '../data/schedule_service.dart';

class AddSchedulePage extends StatefulWidget {
  final ScheduleItem? scheduleItem;

  const AddSchedulePage({
    super.key,
    this.scheduleItem,
  });

  @override
  State<AddSchedulePage> createState() => _AddSchedulePageState();
}

class _AddSchedulePageState extends State<AddSchedulePage> {
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  bool _isAllDay = false;
  bool _isSaving = false;
  
  // 日程服务
  final ScheduleService _scheduleService = ScheduleService();

  @override
  void initState() {
    super.initState();
    // 如果是编辑模式，使用现有数据初始化
    if (widget.scheduleItem != null) {
      final item = widget.scheduleItem!;
      _selectedDate = DateTime(
        item.startTime.year,
        item.startTime.month,
        item.startTime.day,
      );
      _startTime = TimeOfDay(
        hour: item.startTime.hour,
        minute: item.startTime.minute,
      );
      _endTime = TimeOfDay(
        hour: item.endTime.hour,
        minute: item.endTime.minute,
      );
      _titleController = TextEditingController(text: item.title);
      _descriptionController = TextEditingController(text: item.description ?? '');
      _locationController = TextEditingController(text: item.location ?? '');
      _isAllDay = item.isAllDay;
    } else {
      // 新建模式使用默认值
      _selectedDate = DateTime.now();
      _startTime = TimeOfDay.now();
      // 默认结束时间为开始时间后1小时
      final now = DateTime.now();
      final endTime = DateTime(now.year, now.month, now.day, 
                               now.hour + 1, now.minute);
      _endTime = TimeOfDay(hour: endTime.hour, minute: endTime.minute);
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _locationController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          // 如果开始时间大于结束时间，自动调整结束时间
          if (_isTimeAfter(_startTime, _endTime)) {
            // 设置结束时间为开始时间后1小时
            _endTime = TimeOfDay(
              hour: (_startTime.hour + 1) % 24,
              minute: _startTime.minute,
            );
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  // 检查时间1是否晚于时间2
  bool _isTimeAfter(TimeOfDay time1, TimeOfDay time2) {
    return time1.hour > time2.hour || 
          (time1.hour == time2.hour && time1.minute >= time2.minute);
  }

  // 保存日程
  Future<void> _saveSchedule() async {
    // 表单验证
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入日程标题')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 获取当前活跃的日历本ID
      final calendarManager = Provider.of<CalendarBookManager>(
        context, 
        listen: false
      );
      final activeCalendarId = calendarManager.activeBook?.id;
      
      // 添加调试输出
      print('活跃日历本ID: $activeCalendarId');
      
      if (activeCalendarId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到活跃的日历本')),
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }

      // 创建开始时间和结束时间的DateTime对象
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _isAllDay ? 0 : _startTime.hour,
        _isAllDay ? 0 : _startTime.minute,
      );
      
      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _isAllDay ? 23 : _endTime.hour,
        _isAllDay ? 59 : _endTime.minute,
      );
      
      // 添加调试输出
      print('开始时间: $startDateTime');
      print('结束时间: $endDateTime');
      
      // 创建新的日程项
      final ScheduleItem newSchedule = widget.scheduleItem == null
          ? ScheduleItem(
              calendarId: activeCalendarId,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              startTime: startDateTime,
              endTime: endDateTime,
              isAllDay: _isAllDay,
              location: _locationController.text.trim().isEmpty 
                ? null 
                : _locationController.text.trim(),
            )
          : widget.scheduleItem!.copyWith(
              calendarId: activeCalendarId,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              startTime: startDateTime,
              endTime: endDateTime,
              isAllDay: _isAllDay,
              location: _locationController.text.trim().isEmpty 
                ? null 
                : _locationController.text.trim(),
            );
      
      // 添加调试输出
      print('准备保存日程: ${newSchedule.title}');
      
      // 保存到数据库
      if (widget.scheduleItem == null) {
        // 新增日程
        print('调用添加日程方法');
        await _scheduleService.addSchedule(newSchedule);
        print('日程添加成功');
      } else {
        // 更新现有日程
        print('调用更新日程方法');
        await _scheduleService.updateSchedule(newSchedule);
        print('日程更新成功');
      }
      
      // 返回上一页，并传递保存成功的标志
      if (mounted) {
        print('导航返回上一页，结果为true');
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('保存日程时出错: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.scheduleItem == null ? '添加日程' : '编辑日程',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.primary,
        ),
        actions: [
          _isSaving
            ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              )
            : TextButton(
                onPressed: _saveSchedule,
                child: Text(
                  '保存',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期选择
            _buildSectionTitle('日期'),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),

            // 全天选项
            _buildSectionTitle('全天事件'),
            Row(
              children: [
                Switch(
                  value: _isAllDay,
                  onChanged: (value) {
                    setState(() {
                      _isAllDay = value;
                    });
                  },
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
                Text(_isAllDay ? '是' : '否', 
                     style: const TextStyle(fontSize: 16)),
              ],
            ),
            const Divider(),

            // 时间选择 (仅在非全天事件时显示)
            if (!_isAllDay) ...[
              _buildSectionTitle('时间'),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Text(' - '),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(),
            ],

            // 标题输入
            _buildSectionTitle('标题'),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '请输入日程标题',
                border: InputBorder.none,
              ),
            ),
            const Divider(),

            // 地点输入
            _buildSectionTitle('地点'),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                hintText: '请输入地点',
                border: InputBorder.none,
              ),
            ),
            const Divider(),

            // 备注输入
            _buildSectionTitle('描述'),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '请输入描述信息',
                border: InputBorder.none,
              ),
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }
} 