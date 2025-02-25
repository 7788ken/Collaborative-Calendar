import 'package:flutter/material.dart';
import '../data/models/schedule_item.dart';

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
  late final TextEditingController _remarkController;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    // 如果是编辑模式，使用现有数据初始化
    if (widget.scheduleItem != null) {
      final item = widget.scheduleItem!;
      _selectedDate = item.date;
      final times = item.time.split(' - ');
      _startTime = _parseTimeString(times[0]);
      _endTime = _parseTimeString(times[1]);
      _titleController = TextEditingController(text: item.title);
      _remarkController = TextEditingController(text: item.remark);
      _locationController = TextEditingController(text: item.location);
    } else {
      // 新建模式使用默认值
      _selectedDate = DateTime.now();
      _startTime = TimeOfDay.now();
      _endTime = TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);
      _titleController = TextEditingController();
      _remarkController = TextEditingController();
      _locationController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _remarkController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
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
          if (_startTime.hour > _endTime.hour || 
              (_startTime.hour == _endTime.hour && _startTime.minute >= _endTime.minute)) {
            _endTime = _startTime.replacing(hour: _startTime.hour + 1);
          }
        } else {
          _endTime = picked;
        }
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
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scheduleItem == null ? '添加日程' : '编辑日程'),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: 保存日程
              Navigator.pop(context);
            },
            child: const Text('保存'),
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
                    const Icon(Icons.calendar_today, size: 20),
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

            // 时间选择
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
                          const Icon(Icons.access_time, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _startTime.format(context),
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
                          const Icon(Icons.access_time, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _endTime.format(context),
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
            _buildSectionTitle('备注'),
            TextField(
              controller: _remarkController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '请输入备注信息',
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