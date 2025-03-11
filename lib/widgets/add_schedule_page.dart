import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/schedule_item.dart';
import '../data/calendar_book_manager.dart';
import '../data/schedule_service.dart';
import 'package:uuid/uuid.dart';

class AddSchedulePage extends StatefulWidget {
  final ScheduleItem? scheduleItem;

  const AddSchedulePage({super.key, this.scheduleItem});

  @override
  State<AddSchedulePage> createState() => _AddSchedulePageState();
}

class _AddSchedulePageState extends State<AddSchedulePage> {
  // 添加表单Key用于验证
  final _formKey = GlobalKey<FormState>();

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
      // 添加调试日志，显示传入的日程项信息

      _selectedDate = DateTime(item.startTime.year, item.startTime.month, item.startTime.day);
      _startTime = TimeOfDay(hour: item.startTime.hour, minute: item.startTime.minute);
      _endTime = TimeOfDay(hour: item.endTime.hour, minute: item.endTime.minute);
      _titleController = TextEditingController(text: item.title);
      _descriptionController = TextEditingController(text: item.description ?? '');
      _locationController = TextEditingController(text: item.location ?? '');
      _isAllDay = item.isAllDay == 1;
    } else {
      // 新建模式使用默认值
      _selectedDate = DateTime.now();
      _startTime = TimeOfDay.now();
      // 默认结束时间为开始时间后1小时
      final now = DateTime.now();
      final endTime = DateTime(now.year, now.month, now.day, now.hour + 1, now.minute);
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
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _startTime : _endTime);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          // 如果开始时间大于结束时间，自动调整结束时间
          if (_isTimeAfter(_startTime, _endTime)) {
            // 设置结束时间为开始时间后1小时
            _endTime = TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: _startTime.minute);
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  // 检查时间1是否晚于时间2
  bool _isTimeAfter(TimeOfDay time1, TimeOfDay time2) {
    return time1.hour > time2.hour || (time1.hour == time2.hour && time1.minute >= time2.minute);
  }

  Future<bool> _saveToDatabase() async {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 获取日历管理器
      final calendarManager = Provider.of<CalendarBookManager>(context, listen: false);

      // 添加调试日志，显示当前活动日历本和要编辑的日程日历本
      if (widget.scheduleItem != null) {}

      // 根据是新建还是编辑选择不同的处理逻辑
      if (widget.scheduleItem == null) {
        // 新建日程
        return await _createNewSchedule(calendarManager);
      } else {
        // 编辑现有日程
        return await _updateExistingSchedule(calendarManager);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
      setState(() {
        _isSaving = false;
      });
      return false;
    }
  }

  // 创建新日程
  Future<bool> _createNewSchedule(CalendarBookManager calendarManager) async {
    try {
      // 检查日历本是否为共享日历
      final isSharedCalendar = calendarManager.activeBook?.isShared ?? false;

      // 创建新日程项
      final newSchedule = ScheduleItem(
        id: Uuid().v4(),
        calendarId: calendarManager.activeBook!.id,
        title: _titleController.text.trim(),
        startTime: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startTime.hour, _startTime.minute),
        endTime: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime.hour, _endTime.minute),
        isAllDay: _isAllDay,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text.trim(),
        location: _locationController.text.isEmpty ? null : _locationController.text.trim(),
        isSynced: !isSharedCalendar, // 如果是共享日历，初始状态为未同步
      );

      // 添加调试输出

      // 保存到数据库
      try {
        await _scheduleService.addSchedule(newSchedule);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('添加失败: ${e.toString()}')));
        }
        setState(() {
          _isSaving = false;
        });
        return false;
      }

      // 判断是否需要同步到云端
      await _syncToCloudIfNeeded(calendarManager, newSchedule);

      // 返回上一页
      return _finishAndReturnSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
      }
      setState(() {
        _isSaving = false;
      });
      return false;
    }
  }

  // 更新现有日程
  Future<bool> _updateExistingSchedule(CalendarBookManager calendarManager) async {
    try {
      // 确保使用原始日程的ID和日历本ID
      final originalItem = widget.scheduleItem!;

      // 首先从数据库中查询该日程的真实信息，确保获取正确的日历本ID
      final scheduleId = originalItem.id;

      final dbSchedules = await _scheduleService.getScheduleById(scheduleId);
      if (dbSchedules.isEmpty) {
        throw Exception('在数据库中未找到该日程');
      }

      final dbSchedule = dbSchedules.first;
      final realCalendarId = dbSchedule.calendarId;

      if (realCalendarId != originalItem.calendarId) {}

      // 创建更新后的日程项，显式强制使用数据库中的日历本ID
      final updatedSchedule = ScheduleItem(
        id: scheduleId, // 保持原ID
        calendarId: realCalendarId, // 强制使用数据库中的日历本ID
        title: _titleController.text.trim(),
        startTime: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startTime.hour, _startTime.minute),
        endTime: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime.hour, _endTime.minute),
        isAllDay: _isAllDay,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text.trim(),
        location: _locationController.text.isEmpty ? null : _locationController.text.trim(),
        createdAt: dbSchedule.createdAt, // 使用数据库中的创建时间
        isCompleted: dbSchedule.isCompleted, // 使用数据库中的完成状态
        isSynced: dbSchedule.isSynced, // 保留原始同步状态
        isDeleted: dbSchedule.isDeleted, // 保留原始删除状态
      );

      // 添加调试输出
      print('准备更新日程: ${updatedSchedule.title}');
      print('日程ID: ${updatedSchedule.id}');
      print('日程所属日历本ID: ${updatedSchedule.calendarId}');
      print('日程开始时间: ${updatedSchedule.startTime}');
      print('日程结束时间: ${updatedSchedule.endTime}');
      print('日程完成状态: ${updatedSchedule.isCompleted}');
      print('日程同步状态: ${updatedSchedule.isSynced}');
      print('日程详细信息: ${updatedSchedule.toMap()}');

      // 保存到数据库
      print('调用更新日程方法');
      print('原始日程ID: ${dbSchedule.id}');
      print('更新后日程ID: ${updatedSchedule.id}');
      try {
        await _scheduleService.updateSchedule(updatedSchedule);
        print('日程更新成功');
      } catch (e) {
        print('日程更新失败: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: ${e.toString()}')));
        }
        setState(() {
          _isSaving = false;
        });
        return false;
      }

      // 判断是否需要同步到云端
      await _syncToCloudIfNeeded(calendarManager, updatedSchedule);

      // 返回上一页
      return _finishAndReturnSuccess();
    } catch (e) {
      print('更新日程时出错: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
      setState(() {
        _isSaving = false;
      });
      return false;
    }
  }

  // 判断是否需要同步到云端
  Future<void> _syncToCloudIfNeeded(CalendarBookManager calendarManager, ScheduleItem schedule) async {
    // 检查日历本是否为共享日历
    final calendarBook = calendarManager.books.firstWhere((book) => book.id == schedule.calendarId, orElse: () => throw Exception('未找到ID为 ${schedule.calendarId} 的日历本'));

    // 如果是共享日历且未同步，则需要同步到云端
    if (calendarBook.isShared && !schedule.isSynced) {
      print('日程需要同步到云端: ${schedule.title}');
      // 这里可以添加同步到云端的逻辑
      // 目前仅打印日志，实际实现可以在后续添加
    } else {
      print('日程不需要同步到云端: ${schedule.title}');
    }

    // 无论是否需要同步，都确保本地数据已正确更新
    // 验证数据库中的数据
    final updatedSchedules = await _scheduleService.getScheduleById(schedule.id);
    if (updatedSchedules.isNotEmpty) {
      final updatedSchedule = updatedSchedules.first;
      print('验证数据库中的日程: ${updatedSchedule.toMap()}');
    }
  }

  // 完成操作并返回
  bool _finishAndReturnSuccess() {
    // print('添加日程返回结果为true，准备刷新页面');
    // 返回上一页，并传递保存成功的标志
    if (mounted) {
      // 使用单一的true值作为结果，让调用方知道操作成功
      Navigator.pop(context, true);
    }
    return true;
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.scheduleItem == null ? '添加日程' : '编辑日程', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        actions: [_isSaving ? Padding(padding: const EdgeInsets.all(16.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary)))) : TextButton(onPressed: _saveToDatabase, child: Text(widget.scheduleItem == null ? '保存' : '修改', style: TextStyle(color: Theme.of(context).colorScheme.primary)))],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日期选择
              _buildSectionTitle('日期'),
              InkWell(onTap: _selectDate, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [Icon(Icons.calendar_today, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text('${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日', style: const TextStyle(fontSize: 16))]))),
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
                  Text(_isAllDay ? '是' : '否', style: const TextStyle(fontSize: 16)),
                ],
              ),
              const Divider(),

              // 时间选择 (仅在非全天事件时显示)
              if (!_isAllDay) ...[
                _buildSectionTitle('时间'),
                Row(
                  children: [
                    Expanded(child: InkWell(onTap: () => _selectTime(true), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [Icon(Icons.access_time, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text('${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 16))])))),
                    const Text(' - '),
                    Expanded(child: InkWell(onTap: () => _selectTime(false), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [Icon(Icons.access_time, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text('${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 16))])))),
                  ],
                ),
                const Divider(),
              ],

              // 标题输入
              _buildSectionTitle('标题'),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: '请输入日程标题', border: InputBorder.none),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入日程标题';
                  }
                  return null;
                },
              ),
              const Divider(),

              // 地点输入
              _buildSectionTitle('地点'),
              TextField(controller: _locationController, decoration: const InputDecoration(hintText: '请输入地点', border: InputBorder.none)),
              const Divider(),

              // 备注输入
              _buildSectionTitle('描述'),
              TextField(controller: _descriptionController, maxLines: 3, decoration: const InputDecoration(hintText: '请输入描述信息', border: InputBorder.none)),
              const Divider(),
            ],
          ),
        ),
      ),
    );
  }
}
