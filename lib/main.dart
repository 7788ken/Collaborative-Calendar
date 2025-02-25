import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'pages/schedule/schedule_page.dart';
import 'pages/task/task_page.dart';
import 'pages/profile/profile_page.dart';
import 'widgets/add_schedule_page.dart';

// 添加主题状态管理类
class ThemeProvider with ChangeNotifier {
  static const String _themeColorKey = 'theme_color';
  static const String _fontSizeKey = 'font_size';  // 添加字体大小的存储键
  static const Color _defaultColor = Color(0xFF90EE90); // 浅绿色
  static const double _defaultFontSize = 14.0;  // 默认字体大小

  SharedPreferences? _prefs;  // 改为可空类型
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
    _prefs?.setInt(_themeColorKey, color.value);  // 使用可空调用
    notifyListeners();
  }

  void updateFontSize(double size) {
    _fontSize = size;
    _prefs?.setDouble(_fontSizeKey, size);  // 保存字体大小到本地
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // 确保这行在最前面
  
  try {
    final themeProvider = ThemeProvider();
    await themeProvider.init();  // 等待初始化完成

    runApp(
      ChangeNotifierProvider.value(
        value: themeProvider,
        child: const MyApp(),
      ),
    );
  } catch (e) {
    debugPrint('应用初始化失败: $e');
    // 使用默认设置启动应用
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
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
          title: '日程管理',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeProvider.primaryColor,
            ),
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
  final List<String> _titles = ['日程表', '任务', '我的'];
  
  late final List<Widget> _pages = [
    const SchedulePage(),
    const TaskPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_titles[_currentIndex]),
        actions: [
          if (_currentIndex == 0) // 只在日程表页面显示添加按钮
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddSchedulePage(),
                  ),
                );
              },
            ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.white.withAlpha(77),
          highlightColor: Colors.white.withAlpha(77),
        ),
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
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: '日程表'),
            BottomNavigationBarItem(icon: Icon(Icons.message), label: '任务'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
          ],
        ),
      ),
    );
  }
}
