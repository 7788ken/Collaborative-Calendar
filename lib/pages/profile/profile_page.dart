import 'package:flutter/material.dart';
import 'widgets/menu_item.dart';
import 'about_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
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
              MenuItem(
                icon: Icons.edit,
                title: '编辑资料',
                onTap: () {
                  // TODO: 实现编辑资料功能
                },
              ),
              _buildDivider(),
              MenuItem(
                icon: Icons.calendar_today,
                title: '我的日历 ID',
                subtitle: 'JTRL123456',
                onTap: () {
                  // TODO: 复制日历 ID
                },
              ),
              _buildDivider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('关于'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AboutPage(),
                    ),
                  );
                },
              ),
              _buildDivider(),
              MenuItem(
                icon: Icons.settings,
                title: '设置',
                onTap: () {
                  // TODO: 跳转到设置页面
                },
              ),
            ],
          ),
        ),
      ],
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