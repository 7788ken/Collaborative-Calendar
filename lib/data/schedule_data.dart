import 'models/schedule_item.dart';

// 测试数据
class ScheduleData {
  static final List<ScheduleItem> scheduleItems = [
    // 今天的日程
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
    
    // 明天的日程
    ScheduleItem(
      title: '客户会议',
      startTime: '10:00',
      endTime: '11:30',
      location: '咖啡厅',
      remark: '讨论新需求和合作方案',
      date: DateTime.now().add(const Duration(days: 1)),
    ),
    ScheduleItem(
      title: '技术分享会',
      startTime: '15:00',
      endTime: '16:30',
      location: '会议室B',
      remark: '分享最新的技术趋势和实践经验',
      date: DateTime.now().add(const Duration(days: 1)),
    ),
    
    // 后天的日程
    ScheduleItem(
      title: '产品设计评审',
      startTime: '09:30',
      endTime: '11:00',
      location: '设计部',
      remark: '评审新功能的设计方案',
      date: DateTime.now().add(const Duration(days: 2)),
    ),
    ScheduleItem(
      title: '团队建设活动',
      startTime: '14:30',
      endTime: '17:30',
      location: '城市公园',
      remark: '户外团建活动，请穿运动装',
      date: DateTime.now().add(const Duration(days: 2)),
    ),
    
    // 三天后的日程
    ScheduleItem(
      title: '季度总结会',
      startTime: '10:00',
      endTime: '12:00',
      location: '大会议室',
      remark: '总结本季度工作，规划下季度目标',
      date: DateTime.now().add(const Duration(days: 3)),
    ),
    
    // 四天后的日程
    ScheduleItem(
      title: '项目启动会',
      startTime: '09:00',
      endTime: '10:30',
      location: '会议室C',
      remark: '新项目启动，确定项目目标和分工',
      date: DateTime.now().add(const Duration(days: 4)),
    ),
    
    // 五天后的日程
    ScheduleItem(
      title: '培训课程',
      startTime: '13:30',
      endTime: '16:30',
      location: '培训中心',
      remark: '新技术培训课程，请带笔记本电脑',
      date: DateTime.now().add(const Duration(days: 5)),
    ),
    
    // 一周后的日程
    ScheduleItem(
      title: '战略规划会',
      startTime: '14:00',
      endTime: '17:00',
      location: '总部会议室',
      remark: '讨论下半年战略规划',
      date: DateTime.now().add(const Duration(days: 7)),
    ),
  ];
} 