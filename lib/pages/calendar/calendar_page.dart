import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/calendar_book_manager.dart';
import 'widgets/calendar_grid.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _selectedDay = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  String? _currentActiveCalendarId;

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarBookManager>(
      builder: (context, calendarManager, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                // 日历网格
                CalendarGrid(
                  currentMonth: _currentMonth,
                  selectedDay: _selectedDay,
                  onDateSelected: (date) {
                    setState(() => _selectedDay = date);
                  },
                  onMonthChanged: (month) {
                    setState(() => _currentMonth = month);
                  },
                  scheduleItemsMap: const {}, // 需要根据实际数据源调整
                  getScheduleCountForDate: (_) => 0, // 需要根据实际数据源调整
                ),

                // 底部可拖动面板
                DraggableScrollableSheet(
                  initialChildSize: 0.3,
                  minChildSize: 0.3,
                  maxChildSize: 0.85,
                  snap: true,
                  snapSizes: const [0.3, 0.85],
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 0, offset: const Offset(0, -2))]),
                      child: Column(
                        children: [
                          Container(width: 50, height: 5, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5))),
                          Container(
                            height: 40,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 15),
                                  child: Row(children: [Text(_getDateDescription(_selectedDay), style: const TextStyle(fontSize: 18, color: Color.fromARGB(255, 214, 74, 74), fontWeight: FontWeight.bold)), const SizedBox(width: 10), const Icon(Icons.calendar_today, size: 20), const SizedBox(width: 4), Text('${_selectedDay.year}年${_selectedDay.month}月${_selectedDay.day}日', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: CustomScrollView(
                              controller: scrollController,
                              slivers: [
                                SliverToBoxAdapter(),
                                // 这里可以添加日历特定内容
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getDateDescription(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(date.year, date.month, date.day);
    final difference = selectedDate.difference(today).inDays;

    switch (difference) {
      case 0:
        return '今天行程';
      case 1:
        return '明天行程';
      case 2:
        return '后天行程';
      default:
        return '';
    }
  }
}
