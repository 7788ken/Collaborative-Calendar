import 'models/schedule_item.dart';

// 测试数据
class ScheduleData {
  static final List<ScheduleItem> scheduleItems = [
    ScheduleItem(
      title: '团队周会',
      startTime: '09:00',
      endTime: '10:30',
      location: '线上会议',
      remark: '讨论本周进度和下周计划',
      date: DateTime.now(),
      isCompleted: true,
    ),
    ScheduleItem(
      title: '项目评审',
      startTime: '14:00',
      endTime: '15:00',
      location: '会议室A',
      remark: '准备项目文档和演示材料',
      date: DateTime.now(),
    ),
    ScheduleItem(
      title: '项目评审B',
      startTime: '14:00',
      endTime: '15:00',
      location: '会议室B',
      remark: '',
      date: DateTime.now(),
    ),
    ScheduleItem(
      title: '客户会面',
      startTime: '10:00',
      endTime: '11:30',
      location: '咖啡厅',
      remark: '讨论新需求和合作方案',
      date: DateTime.now(),
    ),
    ScheduleItem(
      title: '产品设计评审',
      startTime: '15:00',
      endTime: '16:30',
      location: '会议室B',
      remark: '',
      date: DateTime.now(),
      isCompleted: true,
    ),
    ScheduleItem(
      title: '团队代码审查',
      startTime: '16:30',
      endTime: '17:30',
      location: '会议室C',
      remark: '',
      date: DateTime.now(),
    ),
    ScheduleItem(
      title: '周报总结',
      startTime: '13:30',
      endTime: '14:30',
      location: '线上会议',
      remark: '',
      date: DateTime.now(),
      isCompleted: true,
    ),
  ];
} 