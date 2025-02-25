import 'package:flutter/material.dart';
import 'widgets/menu_item.dart';
import 'about_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Widget _buildListItem({
    required String title,
    required IconData leadingIcon,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(
        leadingIcon,
        color: Colors.grey[600],
      ),
      title: Text(title),
      trailing: trailing ?? const Icon(
        Icons.chevron_right,  // 统一使用 chevron_right 图标
        color: Colors.grey,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 头像和昵称区域
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 头像
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withAlpha(50),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 昵称
                const Text(
                  '用户昵称',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // 菜单列表
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(20),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildListItem(
                  title: '编辑资料',
                  leadingIcon: Icons.edit,
                  onTap: () {
                    // TODO: 实现编辑资料功能
                  },
                ),
                _buildListItem(
                  title: '我的日历 ID',
                  leadingIcon: Icons.calendar_today,
                  trailing: const Text(
                    'JTRL123456',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildListItem(
                  title: '关于',
                  leadingIcon: Icons.info_outline,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutPage(),
                      ),
                    );
                  },
                ),
                _buildListItem(
                  title: '设置',
                  leadingIcon: Icons.settings,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[200],
      indent: 56,
    );
  }
} 