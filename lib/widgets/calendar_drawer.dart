//侧边栏 日历本管理 抽屉

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/calendar_book_manager.dart';
import '../data/models/calendar_book.dart';
import 'package:intl/intl.dart'; // 添加日期格式化库

class CalendarDrawer extends StatelessWidget {
  const CalendarDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final calendarManager = Provider.of<CalendarBookManager>(context);
    final currentBook = calendarManager.activeBook;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // 头部固定区域
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24), // 为状态栏留出空间
                  const Text('切换日历本', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('当前: ${currentBook?.name ?? ""}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                  //最后更新时间
                  const SizedBox(height: 8),
                  if (currentBook != null && currentBook.updatedAt != null) Text('最后更新: ${_formatDateTime(currentBook.updatedAt)}', style: const TextStyle(color: Colors.white, fontSize: 12)) else const Text('最后更新: 未知', style: TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // 日历本列表(这部份可以上下滑动)
            Expanded(
              // Expanded让列表部分占用剩余空间并可滚动
              child: ListView(
                padding: EdgeInsets.zero,
                children:
                    calendarManager.books
                        .map(
                          (book) => ListTile(
                            title: Text(book.name, overflow: TextOverflow.ellipsis),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    // color: book.color.withAlpha(70),
                                    color: book.isShared ? book.color.withAlpha(20) : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(!book.isShared ? '本地日历' : '云端日历', style: TextStyle(fontSize: 10, color: book.isShared ? book.color.withAlpha(200) : Colors.grey)),
                                ),
                                const SizedBox(width: 4),
                                Builder(
                                  builder: (context) {
                                    // 获取日历最后更新时间
                                    final updateTime = calendarManager.getLastUpdateTime(book.id);
                                    final timeText = updateTime != null ? _formatDateTime(updateTime) : _formatDateTime(book.updatedAt);

                                    return Text('最后更新: $timeText', style: TextStyle(fontSize: 10, color: Colors.blue.shade700));
                                  },
                                ),
                                if (book.isShared) // 显示最后更新时间
                                  Row(
                                    children: [
                                      // 刷新按钮（保持原有的布局结构）
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        height: 12,
                                        width: 12,
                                        child: IconButton(
                                          icon: const Icon(Icons.sync, size: 12, color: Colors.blue),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: '检查更新',
                                          onPressed: () {
                                            // TODO: 实现检查更新功能
                                          },
                                        ),
                                      ),
                                    ],
                                  )
                                else if (!book.isShared)
                                  GestureDetector(
                                    onTap: () {
                                      _shareCalendar(context, book);
                                    },
                                    child: Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)), child: const Text('分享', style: TextStyle(fontSize: 10, color: Colors.blue))),
                                  ),
                              ],
                            ),
                            trailing: book.id == currentBook?.id ? const Icon(Icons.check, color: Colors.green) : null,
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
              ),
            ),

            // 底部固定区域
            const Divider(height: 1),

            // 按钮-创建新日历
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
              title: const Text('创建新日历'),
              onTap: () {
                _showCreateCalendarDialog(context);
              },
            ),

            // 按钮-导入日历
            ListTile(
              leading: const Icon(Icons.file_download_outlined, color: Colors.orange),
              title: const Text('导入日历'),
              onTap: () {
                _showImportCalendarDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 添加一个格式化日期时间的方法，确保处理null值
  String _formatDateTime(DateTime? dateTime) {
    // 如果日期为null，直接返回未知
    if (dateTime == null) return '未知';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    // 今天内的更新显示小时和分钟
    if (difference.inDays == 0) {
      return DateFormat('今天 HH:mm').format(dateTime);
    }

    // 昨天的更新
    if (difference.inDays == 1) {
      return DateFormat('昨天 HH:mm').format(dateTime);
    }

    // 一周内的更新
    if (difference.inDays < 7) {
      return DateFormat('EEEE HH:mm', 'zh_CN').format(dateTime);
    }

    // 今年内的更新
    if (dateTime.year == now.year) {
      return DateFormat('MM-dd HH:mm').format(dateTime);
    }

    // 超过一年的更新
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
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
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: '日历名称', hintText: '输入日历名称')),
                  const SizedBox(height: 16),
                  const Text('选择颜色:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        [Colors.red, Colors.pink, Colors.purple, Colors.deepPurple, Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan, Colors.teal, Colors.green, Colors.lightGreen, Colors.lime, Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange]
                            .map(
                              (color) => GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedColor = color;
                                  });
                                },
                                child: Container(width: 30, height: 30, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: selectedColor == color ? Border.all(color: Colors.black, width: 2) : null)),
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
                      final calendarManager = Provider.of<CalendarBookManager>(context, listen: false);
                      calendarManager.Page_function_createBook(nameController.text.trim(), selectedColor);
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
    final calendarManager = Provider.of<CalendarBookManager>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('导入共享日历'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: idController, decoration: const InputDecoration(labelText: '日历ID', hintText: '输入共享日历ID')), const SizedBox(height: 16), const Text('请输入他人分享给你的日历ID，导入后可以查看和编辑共享日历', style: TextStyle(fontSize: 12, color: Colors.grey))]),
          actions: [
            TextButton(
              onPressed: () {
                navigator.pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (idController.text.trim().isNotEmpty) {
                  final shareCode = idController.text.trim();

                  // 关闭输入对话框
                  navigator.pop();

                  // 关闭侧边栏
                  navigator.pop();

                  // 使用一个变量跟踪对话框是否显示
                  bool isDialogShowing = true;

                  // 显示加载对话框
                  showDialog(
                    context: dialogContext,
                    barrierDismissible: false,
                    builder: (loadingContext) {
                      return WillPopScope(onWillPop: () async => false, child: const AlertDialog(content: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在从云端导入日历...')])));
                    },
                  );

                  try {
                    // 调用API导入日历
                    final success = await calendarManager.importSharedCalendarFromCloud(shareCode);

                    // 如果对话框仍在显示，则关闭它
                    if (isDialogShowing && navigator.mounted) {
                      navigator.pop();
                      isDialogShowing = false;
                    }

                    // 显示导入结果
                    if (success) {
                      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('日历导入成功'), duration: Duration(seconds: 2)));
                    } else {
                      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('导入失败，该日历可能已存在或者分享码无效'), duration: Duration(seconds: 2)));
                    }
                  } catch (e) {
                    // 如果对话框仍在显示，则关闭它
                    if (isDialogShowing && navigator.mounted) {
                      navigator.pop();
                      isDialogShowing = false;
                    }

                    // 根据错误类型提供更有用的错误信息
                    String errorMessage = '导入失败';

                    if (e.toString().contains('网络连接错误') || e.toString().contains('SocketException')) {
                      errorMessage = '网络连接错误，请检查网络后重试';
                    } else if (e.toString().contains('超时')) {
                      errorMessage = '连接服务器超时，请稍后重试';
                    } else if (e.toString().contains('无效') || e.toString().contains('不存在')) {
                      errorMessage = '分享码无效或日历不存在';
                    } else if (e.toString().contains('已存在')) {
                      errorMessage = '该日历已导入，请勿重复导入';
                    }

                    // 使用全局 ScaffoldMessenger 显示结果
                    scaffoldMessenger.showSnackBar(SnackBar(content: Text(errorMessage), duration: const Duration(seconds: 2)));
                  }
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
    final calendarManager = Provider.of<CalendarBookManager>(context, listen: false);
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
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.green),
                title: const Text('复制到新的本地日历'),
                onTap: () {
                  Navigator.pop(context);
                  _copyToNewLocalCalendar(context, book);
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

  // 复制到新的本地日历
  void _copyToNewLocalCalendar(BuildContext context, CalendarBook sourceBook) {
    final nameController = TextEditingController(text: '${sourceBook.name} 副本');
    Color selectedColor = sourceBook.color;
    final calendarManager = Provider.of<CalendarBookManager>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setState) {
            return AlertDialog(
              title: const Text('复制到新日历'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('将创建一个新的本地日历，复制"${sourceBook.name}"中的所有日程', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: '新日历名称', hintText: '输入新日历名称')),
                  const SizedBox(height: 16),
                  const Text('选择颜色:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        [Colors.red, Colors.pink, Colors.purple, Colors.deepPurple, Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan, Colors.teal, Colors.green, Colors.lightGreen, Colors.lime, Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange]
                            .map(
                              (color) => GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedColor = color;
                                  });
                                },
                                child: Container(width: 30, height: 30, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: selectedColor == color ? Border.all(color: Colors.black, width: 2) : null)),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      // 先关闭创建对话框
                      Navigator.of(dialogContext).pop();

                      // 显示加载提示
                      showDialog(
                        context: dialogContext,
                        barrierDismissible: false,
                        builder: (loadingContext) {
                          return const AlertDialog(content: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在复制日历内容...')]));
                        },
                      );

                      try {
                        // 复制日历
                        await calendarManager.copyCalendarBook(sourceBook.id, nameController.text.trim(), selectedColor);

                        // 关闭加载对话框
                        Navigator.of(dialogContext).pop();

                        // 显示成功提示
                        scaffoldMessenger.showSnackBar(SnackBar(content: Text('日历"${nameController.text.trim()}"创建成功')));
                      } catch (e) {
                        // 关闭加载对话框
                        Navigator.of(dialogContext).pop();

                        // 显示错误提示
                        scaffoldMessenger.showSnackBar(SnackBar(content: Text('复制日历失败: $e')));
                      }
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
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: '日历名称')),
                  const SizedBox(height: 16),
                  const Text('选择颜色:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        [Colors.red, Colors.pink, Colors.purple, Colors.deepPurple, Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan, Colors.teal, Colors.green, Colors.lightGreen, Colors.lime, Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange]
                            .map(
                              (color) => GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedColor = color;
                                  });
                                },
                                child: Container(width: 30, height: 30, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: selectedColor == color ? Border.all(color: Colors.black, width: 2) : null)),
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
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      final calendarManager = Provider.of<CalendarBookManager>(context, listen: false);

                      // 显示加载指示器
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return const AlertDialog(content: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在保存...')]));
                        },
                      );

                      try {
                        // 使用新方法同时更新名称和颜色
                        await calendarManager.updateBookNameAndColor(book.id, nameController.text.trim(), selectedColor);

                        // 关闭加载对话框
                        Navigator.of(context).pop();

                        // 关闭编辑对话框
                        Navigator.of(context).pop();

                        // 显示成功消息
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('日历已更新')));
                      } catch (e) {
                        // 关闭加载对话框
                        Navigator.of(context).pop();

                        // 显示错误消息
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: $e')));
                      }
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
  void _showShareCalendarDialog(BuildContext context, CalendarBook? book) {
    if (book == null) return;

    // 获取分享码
    final calendarManager = Provider.of<CalendarBookManager>(context, listen: false);
    final shareId = calendarManager.getShareId(book.id);

    // 获取最后更新时间
    final updateTime = calendarManager.getLastUpdateTime(book.id);
    String timeText = '未同步';

    if (updateTime != null) {
      // 格式化为本地时间
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final updateDate = DateTime(updateTime.year, updateTime.month, updateTime.day);

      if (updateDate.isAtSameMomentAs(today)) {
        // 今天更新的，只显示时间
        timeText = '今天 ${updateTime.hour.toString().padLeft(2, '0')}:${updateTime.minute.toString().padLeft(2, '0')}';
      } else if (updateDate.isAfter(today.subtract(const Duration(days: 7)))) {
        // 一周内，显示星期几
        final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final weekday = weekdays[(updateTime.weekday - 1) % 7];
        timeText = '$weekday ${updateTime.hour.toString().padLeft(2, '0')}:${updateTime.minute.toString().padLeft(2, '0')}';
      } else {
        // 更早的时间，显示完整日期
        timeText = '${updateTime.year}/${updateTime.month.toString().padLeft(2, '0')}/${updateTime.day.toString().padLeft(2, '0')} ${updateTime.hour.toString().padLeft(2, '0')}:${updateTime.minute.toString().padLeft(2, '0')}';
      }
    }

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                child: Row(
                  children: [
                    Expanded(child: SelectableText(shareId ?? '未找到分享码', style: const TextStyle(fontWeight: FontWeight.bold))),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        if (shareId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分享码不存在'), backgroundColor: Colors.red, duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating));
                          return;
                        }
                        // 使用 Clipboard 复制到剪贴板
                        await Clipboard.setData(ClipboardData(text: shareId));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分享码已复制到剪贴板'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating));
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [const Icon(Icons.update, size: 16, color: Colors.grey), const SizedBox(width: 4), Text('最后更新: $timeText', style: const TextStyle(color: Colors.grey))]),
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
                final calendarManager = Provider.of<CalendarBookManager>(context, listen: false);
                calendarManager.deleteBook(book.id);
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('日历已删除')));
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  // 分享日历功能
  Future<void> _shareCalendar(BuildContext context, CalendarBook book) async {
    // 二次确认对话框
    bool shouldProceed =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('确认分享日历'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_upload_outlined, color: Colors.blue, size: 48),
                  const SizedBox(height: 16),
                  Text('您即将将"${book.name}"从本地日历上传到云端', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text('上传后：', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('• 此日历将变为云端日历'),
                  const Text('• 拥有分享码的所有人可以查看和编辑此日历中的日程'),
                  const Text('• 所有修改将在共享用户之间同步'),
                  const SizedBox(height: 12),
                  const Text('确定要分享此日历吗？', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false); // 取消
                  },
                  child: const Text('取消'),
                ),
                TextButton(
                  style: TextButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.of(context).pop(true); // 确认
                  },
                  child: const Text('确认分享'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldProceed) {
      return; // 用户取消了分享
    }

    // 显示加载提示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(content: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在将日历上传至云端...')]));
      },
    );

    // 将日历标记为已分享
    final calendarManager = Provider.of<CalendarBookManager>(context, listen: false);

    try {
      // 使用API服务上传日历到云端并获取分享码
      final serverShareId = await calendarManager.shareCalendarToCloud(book.id);

      // 关闭加载对话框
      Navigator.of(context).pop();

      // 显示分享成功对话框（使用服务器返回的分享码）
      _showShareCalendarSuccessDialog(context, book, serverShareId);
    } catch (e) {
      // 关闭加载对话框
      Navigator.of(context).pop();

      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('分享失败: $e')));
    }
  }

  // 显示分享成功对话框（使用服务器返回的分享码）
  void _showShareCalendarSuccessDialog(BuildContext context, CalendarBook book, String serverShareId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('分享日历成功'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
              const SizedBox(height: 16),
              Text('"${book.name}" 已成功上传到云端', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const Text('将此分享码分享给好友，他们可以导入并查看此日历:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4), color: Colors.blue.shade50),
                child: Row(
                  children: [
                    Expanded(child: SelectableText(serverShareId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        // 使用 Clipboard 复制到剪贴板
                        await Clipboard.setData(ClipboardData(text: serverShareId));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分享码已复制到剪贴板'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating));
                        }
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
}
