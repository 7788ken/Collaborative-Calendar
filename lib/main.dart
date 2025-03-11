import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 添加 services 包导入
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'pages/schedule/schedule_page.dart';
import 'pages/task/task_page.dart';
import 'pages/profile/profile_page.dart';
import 'pages/calendar/calendar_page.dart'; // 添加日历页面导入
import 'widgets/add_schedule_page.dart';
import 'widgets/calendar_drawer.dart'; // 导入新的日历抽屉组件
import 'data/calendar_book_manager.dart';
import 'data/models/calendar_book.dart';
import 'data/schedule_data.dart';
import 'utils/sync_helper.dart'; // 添加 SyncHelper 导入
import 'data/schedule_service.dart';
import 'data/database/database_helper.dart';
// import 'package:flutter/rendering.dart';

// 添加主题状态管理类
class ThemeProvider with ChangeNotifier {
  static const String _themeColorKey = 'theme_color';
  static const String _fontSizeKey = 'font_size'; // 添加字体大小的存储键
  static const Color _defaultColor = Color(0xFF90EE90); // 浅绿色
  static const double _defaultFontSize = 14.0; // 默认字体大小

  SharedPreferences? _prefs; // 改为可空类型
  Color _primaryColor = _defaultColor;
  double _fontSize = _defaultFontSize;

  Color get primaryColor => _primaryColor;
  double get fontSize => _fontSize;

  // 初始化方法
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // 从本地存储读取主题色
      final colorValue = _prefs?.getInt(_themeColorKey);
      if (colorValue != null) {
        _primaryColor = Color(colorValue);
      }

      // 从本地存储读取字体大小
      final fontSize = _prefs?.getDouble(_fontSizeKey);
      if (fontSize != null) {
        _fontSize = fontSize;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('初始化主题设置失败: $e');
    }
  }

  void updateTheme(Color color) {
    _primaryColor = color;
    // 保存到本地存储
    _prefs?.setInt(_themeColorKey, color.value); // 使用可空调用
    notifyListeners();
  }

  void updateFontSize(double size) {
    _fontSize = size;
    _prefs?.setDouble(_fontSizeKey, size); // 保存字体大小到本地
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 确保这行在最前面

  try {
    // 重置数据库以解决表结构问题
    // final dbHelper = DatabaseHelper();
    // try {
    //   await dbHelper.resetDatabase();
    //   debugPrint('数据库已重置，表结构已更新');
    // } catch (e) {
    //   debugPrint('重置数据库失败: $e');
    //   // 继续执行，尝试正常初始化
    // }

    final themeProvider = ThemeProvider();
    await themeProvider.init(); // 等待初始化完成

    final calendarBookManager = CalendarBookManager();
    await calendarBookManager.init(); // 初始化日历本管理器

    // 初始化 ScheduleData
    final scheduleData = ScheduleData();
    await scheduleData.loadTaskCompletionStatus(); // 加载任务完成状态

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: calendarBookManager),
          ChangeNotifierProvider.value(value: scheduleData), // 添加 ScheduleData Provider
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    debugPrint('应用初始化失败: $e');
    // 使用默认设置启动应用
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => CalendarBookManager()),
          ChangeNotifierProvider(create: (_) => ScheduleData()), // 添加 ScheduleData Provider
        ],
        child: const MyApp(),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: '日历',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: themeProvider.primaryColor),
            textTheme: TextTheme(
              // 只对这些样式应用自定义字体大小
              bodyLarge: TextStyle(fontSize: themeProvider.fontSize),
              bodyMedium: TextStyle(fontSize: themeProvider.fontSize),
              bodySmall: TextStyle(fontSize: themeProvider.fontSize * 0.85),
              titleLarge: TextStyle(fontSize: themeProvider.fontSize * 1.5),
              titleMedium: TextStyle(fontSize: themeProvider.fontSize * 1.25),
              titleSmall: TextStyle(fontSize: themeProvider.fontSize * 1.1),
            ).apply(
              // 设置默认字体大小，不影响已固定大小的文字
              bodyColor: Colors.black87,
              displayColor: Colors.black87,
            ),
            useMaterial3: true,
          ),
          home: const MainPage(),
        );
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final List<String> _titles = ['日历', '任务', '我的'];

  late final List<Widget> _pages = [
    const CalendarPage(), // 日历页面
    const TaskPage(), // 任务页面
    const ProfilePage(), // 个人信息页面
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leadingWidth: 96,
        leading: Row(
          children: [
            Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(Icons.menu_book_outlined),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ); // 添加日历本切换按钮
              },
            ),
          ],
        ),
        title: Center(
          child: Builder(
            builder: (context) {
              // 只在日历页面显示日历名称，其他页面显示标题
              if (_currentIndex == 0) {
                final calendarManager = Provider.of<CalendarBookManager>(context);
                final currentBook = calendarManager.activeBook;

                return Center(
                  child: InkWell(
                    onTap: () {
                      Scaffold.of(context).openDrawer();
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 8), if (currentBook != null) Text(currentBook.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)]),
                        if (currentBook != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!currentBook.isShared)
                                Container(margin: const EdgeInsets.only(top: 2), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: const Text('本地日历', style: TextStyle(fontSize: 10, color: Colors.grey)))
                              else
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(margin: const EdgeInsets.only(top: 2), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)), child: const Text('云端日历', style: TextStyle(fontSize: 10, color: Colors.blue))),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        // TODO: 实现分享日历功能
                                      },
                                      child: Container(margin: const EdgeInsets.only(top: 2), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4)), child: const Text('分享', style: TextStyle(fontSize: 10, color: Colors.blue))),
                                    ),
                                  ],
                                ),
                              if (!currentBook.isShared)
                                GestureDetector(
                                  onTap: () {
                                    // TODO: 实现分享日历功能
                                  },
                                  child: Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)), child: const Text('分享', style: TextStyle(fontSize: 10, color: Colors.blue))),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              } else {
                // 其他页面显示普通标题
                return Center(child: Text(_titles[_currentIndex]));
              }
            },
          ),
        ),
        centerTitle: true,
        actions: [
          SizedBox(
            width: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 添加刷新按钮，仅在日历页面显示
                if (_currentIndex != 2)
                  Consumer<CalendarBookManager>(
                    builder: (context, calendarManager, _) {
                      final activeBook = calendarManager.activeBook;
                      // 只有共享日历才显示刷新按钮
                      if (activeBook != null && activeBook.isShared) {
                        return IconButton(
                          icon: const Icon(Icons.sync),
                          tooltip: '检查日历更新',
                          onPressed: () {
                            // TODO: 实现检查日历更新功能
                          },
                        );
                      } else {
                        return const SizedBox(); // 如果不是共享日历，则不显示按钮
                      }
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    // 添加日程按钮
                    // TODO: 实现添加日程功能
                  },
                ), // 添加日程按钮
              ],
            ),
          ),
        ],
      ),
      drawer: const CalendarDrawer(), // 使用新的日历抽屉组件
      body: _pages[_currentIndex],
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(splashColor: Colors.white.withAlpha(77), highlightColor: Colors.white.withAlpha(77)),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          selectedItemColor: Colors.black87,
          unselectedItemColor: Colors.grey[600],
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: '日历'), BottomNavigationBarItem(icon: Icon(Icons.message), label: '任务'), BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的')],
        ),
      ),
    );
  }
}

// 初始化providers
// ... existing code ...
