import 'package:flutter/material.dart';
import 'widgets/menu_item.dart';

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
              MenuItem(
                icon: Icons.info_outline,
                title: '关于 App',
                onTap: () {
                  // TODO: 显示关于页面
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