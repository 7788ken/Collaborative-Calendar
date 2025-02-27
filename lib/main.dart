import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'pages/schedule/schedule_page.dart';
import 'pages/task/task_page.dart';
import 'pages/profile/profile_page.dart';
import 'widgets/add_schedule_page.dart';
import 'data/calendar_book_manager.dart';
import 'data/models/calendar_book.dart';
import 'data/schedule_data.dart'; // 添加 ScheduleData 导入

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
  final List<String> _titles = ['日历', '任务', '我的'];

  late final List<Widget> _pages = [
    const SchedulePage(), // 首页放日历页面
    const TaskPage(), // 任务页面
    const ProfilePage(), // 个人信息页面
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu_book_outlined),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        title: Builder(
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (currentBook != null)
                        Icon(
                          Icons.book,
                          color: currentBook.color,
                          size: 20,
                        ),
                      const SizedBox(width: 8),
                      if (currentBook != null)
                        Text(
                          currentBook.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (currentBook?.isShared == true)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: currentBook!.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '共享',
                            style: TextStyle(
                              fontSize: 10,
                              color: currentBook.color,
                            ),
                          ),
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
        actions: [
          IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                Navigator.push( // 添加日程按钮
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddSchedulePage(),
                  ),
                ).then((result) {
                  // 如果返回结果为true，表示已成功添加或编辑日程，刷新页面
                  if (result == true) {
                    print('添加日程返回结果为true，准备刷新页面');
                    
                    // 如果当前是日历页面，刷新日历
                    if (_currentIndex == 0) {
                      print('刷新日历页面');
                      SchedulePage.refreshSchedules(context);
                    }
                    
                    // 无论在哪个页面，都刷新任务页面
                    print('刷新任务页面');
                    // 添加延迟确保数据库操作完成
                    Future.delayed(const Duration(milliseconds: 500), () {
                      TaskPage.refreshTasks(context);
                    });
                  }
                });
              },
            ),
        ],
      ),
      drawer: _buildCalendarDrawer(context),
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
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: '日历',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.message), label: '任务'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarDrawer(BuildContext context) {
    final calendarManager = Provider.of<CalendarBookManager>(context);
    final currentBook = calendarManager.activeBook;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '切换日历本',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '当前: ${currentBook?.name ?? ""}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),

          // 日历本列表
          ...calendarManager.books
              .map(
                (book) => ListTile(
                  leading: Icon(Icons.book, color: book.color),
                  title: Text(book.name),
                  subtitle:
                      book.isShared
                          ? const Text('共享日历', style: TextStyle(fontSize: 12))
                          : null,
                  trailing:
                      book.id == currentBook?.id
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                  onTap: () {
                    calendarManager.setActiveBook(book.id);
                    Navigator.pop(context);
                  },
                  onLongPress: () {
                    _showCalendarOptions(context, book);
                  },
                ),
              )
              .toList(),

          const Divider(),

          // 创建新日历
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
            title: const Text('创建新日历'),
            onTap: () {
              _showCreateCalendarDialog(context);
            },
          ),

          // 导入日历
          ListTile(
            leading: const Icon(
              Icons.file_download_outlined,
              color: Colors.orange,
            ),
            title: const Text('导入日历'),
            onTap: () {
              _showImportCalendarDialog(context);
            },
          ),
        ],
      ),
    );
  }

  // 显示创建日历对话框
  void _showCreateCalendarDialog(BuildContext context) {
    final nameController = TextEditingController();
    Color selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('创建新日历'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '日历名称',
                      hintText: '输入日历名称',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('选择颜色:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        [
                              Colors.red,
                              Colors.pink,
                              Colors.purple,
                              Colors.deepPurple,
                              Colors.indigo,
                              Colors.blue,
                              Colors.lightBlue,
                              Colors.cyan,
                              Colors.teal,
                              Colors.green,
                              Colors.lightGreen,
                              Colors.lime,
                              Colors.yellow,
                              Colors.amber,
                              Colors.orange,
                              Colors.deepOrange,
                            ]
                            .map(
                              (color) => GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedColor = color;
                                  });
                                },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border:
                                        selectedColor == color
                                            ? Border.all(
                                              color: Colors.black,
                                              width: 2,
                                            )
                                            : null,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      final calendarManager = Provider.of<CalendarBookManager>(
                        context,
                        listen: false,
                      );
                      calendarManager.createBook(
                        nameController.text.trim(),
                        selectedColor,
                      );
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('创建'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 显示导入日历对话框
  void _showImportCalendarDialog(BuildContext context) {
    final idController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('导入共享日历'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  labelText: '日历ID',
                  hintText: '输入共享日历ID',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '请输入他人分享给你的日历ID，导入后可以查看和编辑共享日历',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                // 在实际应用中，这里需要调用API验证ID并获取日历信息
                if (idController.text.trim().isNotEmpty) {
                  final calendarManager = Provider.of<CalendarBookManager>(
                    context,
                    listen: false,
                  );
                  // 这里为了演示，使用模拟数据
                  final success = calendarManager.importSharedBook(
                    idController.text.trim(),
                    '导入的日历 - ${idController.text.substring(0, 4)}',
                    Colors.purple,
                    'user123',
                  );

                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success == true ? '日历导入成功' : '导入失败，该日历已存在'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('导入'),
            ),
          ],
        );
      },
    );
  }

  // 显示日历选项菜单
  void _showCalendarOptions(BuildContext context, CalendarBook book) {
    final calendarManager = Provider.of<CalendarBookManager>(
      context,
      listen: false,
    );
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit, color: book.color),
                title: const Text('编辑日历'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditCalendarDialog(context, book);
                },
              ),
              if (!book.isShared)
                ListTile(
                  leading: const Icon(Icons.share, color: Colors.blue),
                  title: const Text('分享日历'),
                  onTap: () {
                    Navigator.pop(context);
                    _showShareCalendarDialog(context, book);
                  },
                ),
              if (calendarManager.books.length > 1)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('删除日历'),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteCalendarDialog(context, book);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // 显示编辑日历对话框
  void _showEditCalendarDialog(BuildContext context, CalendarBook book) {
    final nameController = TextEditingController(text: book.name);
    Color selectedColor = book.color;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('编辑日历'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '日历名称'),
                  ),
                  const SizedBox(height: 16),
                  const Text('选择颜色:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        [
                              Colors.red,
                              Colors.pink,
                              Colors.purple,
                              Colors.deepPurple,
                              Colors.indigo,
                              Colors.blue,
                              Colors.lightBlue,
                              Colors.cyan,
                              Colors.teal,
                              Colors.green,
                              Colors.lightGreen,
                              Colors.lime,
                              Colors.yellow,
                              Colors.amber,
                              Colors.orange,
                              Colors.deepOrange,
                            ]
                            .map(
                              (color) => GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedColor = color;
                                  });
                                },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border:
                                        selectedColor == color
                                            ? Border.all(
                                              color: Colors.black,
                                              width: 2,
                                            )
                                            : null,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      final calendarManager = Provider.of<CalendarBookManager>(
                        context,
                        listen: false,
                      );
                      calendarManager.updateBookName(
                        book.id,
                        nameController.text.trim(),
                      );
                      calendarManager.updateBookColor(book.id, selectedColor);
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 显示分享日历对话框
  void _showShareCalendarDialog(BuildContext context, CalendarBook book) {
    final calendarManager = Provider.of<CalendarBookManager>(
      context,
      listen: false,
    );
    final shareId = calendarManager.getShareId(book.id);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('分享日历'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('将此ID分享给好友，他们可以导入并查看此日历:'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        shareId,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        // 在实际应用中，这里应该调用剪贴板API
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制到剪贴板')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  // 显示删除日历确认对话框
  void _showDeleteCalendarDialog(BuildContext context, CalendarBook book) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除日历'),
          content: Text('确定要删除"${book.name}"吗？此操作不可撤销，日历中的所有事件将被永久删除。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                final calendarManager = Provider.of<CalendarBookManager>(
                  context,
                  listen: false,
                );
                calendarManager.deleteBook(book.id);
                Navigator.of(context).pop();

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('日历已删除')));
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }
}
