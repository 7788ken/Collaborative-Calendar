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
      print('编辑模式: 接收到的日程项信息:');
      print('  ID: ${item.id}');
      print('  标题: ${item.title}');
      print('  日历本ID: ${item.calendarId}');
      print('  开始时间: ${item.startTime}');
      print('  结束时间: ${item.endTime}');

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
      if (widget.scheduleItem != null) {
        print('编辑日程: 当前活动日历本ID=${calendarManager.activeBook!.id}');
        print('编辑日程: 原始日程所属日历本ID=${widget.scheduleItem!.calendarId}');
      }

      // 根据是新建还是编辑选择不同的处理逻辑
      if (widget.scheduleItem == null) {
        // 新建日程
        return await _createNewSchedule(calendarManager);
      } else {
        // 编辑现有日程
        return await _updateExistingSchedule(calendarManager);
      }
    } catch (e) {
      print('保存日程时出错: $e');
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
      print('准备创建新日程: ${newSchedule.title}');
      print('日程ID: ${newSchedule.id}');
      print('日程所属日历本ID: ${newSchedule.calendarId}');
      print('是否为共享日历: $isSharedCalendar');
      print('初始同步状态: ${newSchedule.isSynced}');
      print('日程详细信息: ${newSchedule.toMap()}');

      // 保存到数据库
      print('调用添加日程方法');
      try {
        await _scheduleService.addSchedule(newSchedule);
        print('日程添加成功');
      } catch (e) {
        print('日程添加失败: $e');
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
      print('创建新日程时出错: $e');
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
      print('从数据库查询日程的真实信息, ID: $scheduleId');

      final dbSchedules = await _scheduleService.getScheduleById(scheduleId);
      if (dbSchedules.isEmpty) {
        print('错误: 在数据库中未找到ID为 $scheduleId 的日程');
        throw Exception('在数据库中未找到该日程');
      }

      final dbSchedule = dbSchedules.first;
      final realCalendarId = dbSchedule.calendarId;

      print('数据库中的日程信息:');
      print('  - ID: ${dbSchedule.id}');
      print('  - 标题: ${dbSchedule.title}');
      print('  - 日历本ID: $realCalendarId');
      print('  - 传入的日历本ID: ${originalItem.calendarId}');

      if (realCalendarId != originalItem.calendarId) {
        print('警告: 传入的日历本ID与数据库中的不一致!');
      }

      // 创建更新后的日程项，显式强制使用数据库中的日历本ID
      print('创建更新后的日程项，强制使用数据库中的日历本ID: $realCalendarId');
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
      );

      // 添加调试输出
      // print('准备更新日程: ${updatedSchedule.title}');
      // print('日程ID: ${updatedSchedule.id}');
      // print('日程所属日历本ID(更新前确认): ${updatedSchedule.calendarId}');
      // print('强制确认日历本ID是否为数据库中的ID: ${updatedSchedule.calendarId == realCalendarId}');
      // print('日程详细信息: ${updatedSchedule.toMap()}');

      // 保存到数据库
      // print('调用更新日程方法');
      // print('原始日程ID: ${dbSchedule.id}');
      // print('更新后日程ID: ${updatedSchedule.id}');
      try {
        await _scheduleService.updateSchedule(updatedSchedule);
        // print('日程更新成功');
      } catch (e) {
        // print('日程更新失败: $e');
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
      // print('更新日程时出错: $e');
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
    try {
      final calendarBook = calendarManager.books.firstWhere((book) => book.id == schedule.calendarId, orElse: () => throw Exception('找不到日历本'));

      // 如果是共享日历，则同步到云端（只同步当前修改的日程）
      if (calendarBook.isShared) {
        // print('日程页面：检测到共享日历的日程变更，准备同步到云端...');
        // print('同步单条日程，ID: ${schedule.id}');

        try {
          // 只同步特定的日程ID，而不是整个日历的所有日程
          await calendarManager.syncSharedCalendarSchedules(schedule.calendarId, specificScheduleId: schedule.id);
          // print('日程页面：云端同步完成');
        } catch (e) {
          // print('日程页面：同步到云端时出错: $e');
          // 但不显示错误，避免影响用户体验
        }
      }
    } catch (e) {
      // print('获取日历本信息时出错: $e');
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
