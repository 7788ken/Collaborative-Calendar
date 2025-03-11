import 'package:flutter/material.dart';
import '../../data/schedule_data.dart';
import 'package:provider/provider.dart';
import '../../main.dart'; // 导入 ThemeProvider

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 主题色选项
  final List<Color> _themeColors = [Colors.blue, Colors.green, Colors.purple, Colors.orange, Colors.pink, Colors.teal];

  // 字体大小选项
  final List<double> _fontSizes = [14, 16, 18, 20];
  double _selectedFontSize = 14.0;

  // 显示颜色选择器对话框
  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('选择自定义颜色', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 预设颜色网格
                Wrap(spacing: 8, runSpacing: 8, children: [Colors.red, Colors.pink, Colors.purple, Colors.deepPurple, Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan, Colors.teal, Colors.green, Colors.lightGreen, Colors.lime, Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange, Colors.brown, Colors.grey, Colors.blueGrey].map((color) => _buildColorItem(color)).toList()),
                const SizedBox(height: 16),
                Text('点击颜色直接选择', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('取消', style: TextStyle(color: Theme.of(context).colorScheme.primary)))],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedFontSize = context.read<ThemeProvider>().fontSize;
  }

  // 更新预览文本
  List<String> _previewTexts = ['这是标题文本', '这是正文内容，可以预览不同大小的显示效果。', '这是小号文字的显示效果'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: Text('设置', style: TextStyle(color: Theme.of(context).colorScheme.primary)), iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary)),
      body: ListView(
        children: [
          // 主题颜色设置
          const _SectionTitle('主题颜色'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // 常用颜色选择
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ..._themeColors.map((color) => _buildColorItem(color)),
                    // 添加自定义颜色按钮
                    InkWell(onTap: () => _showColorPicker(context), child: Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey[300]!, width: 1)), child: Icon(Icons.add, color: Colors.grey[600]))),
                  ],
                ),
                const SizedBox(height: 8),
                Text('点击 + 选择更多颜色', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          const Divider(),
          // 字体大小设置
          const _SectionTitle('字体大小'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Aa', style: TextStyle(fontSize: _fontSizes.first, color: Colors.grey[600])),
                Expanded(
                  child: Slider(
                    value: _selectedFontSize,
                    min: _fontSizes.first,
                    max: _fontSizes.last,
                    divisions: _fontSizes.length - 1,
                    label: _selectedFontSize.toString(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFontSize = value;
                      });
                      context.read<ThemeProvider>().updateFontSize(value);
                    },
                  ),
                ),
                Text('Aa', style: TextStyle(fontSize: _fontSizes.last, color: Colors.grey[600])),
              ],
            ),
          ),
          // 预览文本
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_previewTexts[0], style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8), Text(_previewTexts[1], style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 8), Text(_previewTexts[2], style: Theme.of(context).textTheme.bodySmall)]),
          ),
          const Divider(),
          // 危险区域
          const _SectionTitle('危险区域', color: Colors.red),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 修复统计按钮
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[50],
                    foregroundColor: Colors.orange,
                    minimumSize: const Size.fromHeight(48), // 设置按钮最小高度
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    // TODO: 实现修复统计功能
                  },
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.auto_fix_high), SizedBox(width: 8), Text('修复统计')]),
                ),

                const SizedBox(height: 16),

                // 清空所有日程按钮
                // ElevatedButton(
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.red[50],
                //     foregroundColor: Colors.red,
                //     minimumSize: const Size.fromHeight(48), // 设置按钮最小高度
                //     padding: const EdgeInsets.symmetric(vertical: 12),
                //   ),
                //   onPressed: () => _showClearConfirmDialog(context),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.center,
                //     children: const [
                //       Icon(Icons.delete_forever),
                //       SizedBox(width: 8),
                //       Text('清空所有日程'),
                //     ],
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorItem(Color color) {
    final isSelected = color == Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () {
        context.read<ThemeProvider>().updateTheme(color);
        // 显示设置成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('主题颜色设置成功'),
            backgroundColor: color, // 使用所选颜色作为背景
            duration: const Duration(seconds: 1), // 显示1秒
            behavior: SnackBarBehavior.floating, // 浮动样式
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        Navigator.pop(context); // 关闭颜色选择器对话框
      },
      child: Container(width: 48, height: 48, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3), boxShadow: [BoxShadow(color: color.withAlpha(77), blurRadius: 8, spreadRadius: 1)]), child: isSelected ? const Icon(Icons.check, color: Colors.white) : null),
    );
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('确认清空'),
            content: const Text('此操作将清空所有日程数据，且无法恢复。\n如果确定要清空，请点击确认继续。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showFinalConfirmDialog(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('确认'),
              ),
            ],
          ),
    );
  }

  void _showFinalConfirmDialog(BuildContext context) {
    final firstSchedule = ScheduleData.scheduleItems.firstOrNull;
    if (firstSchedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有日程可清空')));
      return;
    }

    String? inputTitle;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('最终确认'),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('请输入第一条日程的标题以确认清空：'), const SizedBox(height: 8), Text(firstSchedule.title, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)), const SizedBox(height: 16), TextField(onChanged: (value) => inputTitle = value, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '输入标题'))]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              TextButton(
                onPressed: () {
                  if (inputTitle == firstSchedule.title) {
                    // TODO: 实现清空功能
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清空所有日程')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('标题输入不正确')));
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('清空'),
              ),
            ],
          ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final Color? color;

  const _SectionTitle(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(16), child: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)));
  }
}
