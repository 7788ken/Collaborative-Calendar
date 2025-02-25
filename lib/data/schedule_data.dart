import 'models/schedule_item.dart';

// 测试数据
class ScheduleData {
  static final List<ScheduleItem> scheduleItems = [
    ScheduleItem(
      date: DateTime.now(),
      time: '09:00 - 10:30',
      title: '团队周会',
      location: '线上会议',
      remark: '讨论本周进度和下周计划',
      isCompleted: true,
    ),
    ScheduleItem(
      date: DateTime.now(),
      time: '14:00 - 15:00',
      title: '项目评审',
      location: '会议室A',
      remark: '准备项目文档和演示材料',
    ),
    ScheduleItem(
      date: DateTime.now(),
      time: '14:00 - 15:00',
      title: '项目评审B',
      location: '会议室B',
    ),
    ScheduleItem(
      date: DateTime.now().add(const Duration(days: 1)),
      time: '10:00 - 11:30',
      title: '客户会面',
      location: '咖啡厅',
      remark: '讨论新需求和合作方案',
    ),
    ScheduleItem(
      date: DateTime.now().add(const Duration(days: 2)),
      time: '15:00 - 16:30',
      title: '产品设计评审',
      location: '会议室B',
      isCompleted: true,
    ),
    ScheduleItem(
      date: DateTime.now().add(const Duration(days: 2)),
      time: '16:30 - 17:30',
      title: '团队代码审查',
      location: '会议室C',
    ),
    ScheduleItem(
      date: DateTime.now().subtract(const Duration(days: 1)),
      time: '13:30 - 14:30',
      title: '周报总结',
      location: '线上会议',
      isCompleted: true,
    ),
  ];
} 