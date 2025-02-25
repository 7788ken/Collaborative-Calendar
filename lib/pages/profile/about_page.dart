import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '关于',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // APP Logo
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  '日程管理',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'v1.0.0',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // APP 介绍
          const _SectionTitle('应用介绍'),
          const _ContentText(
            '这是一款简洁高效的日程管理应用，帮助您更好地规划和管理每日任务。'
            '通过直观的日历视图和灵活的任务管理功能，让您的时间安排更加有条理。'
          ),
          const SizedBox(height: 24),
          // 核心功能
          const _SectionTitle('核心功能'),
          const _FeatureItem(
            icon: Icons.calendar_month,
            title: '日历视图',
            description: '月份切换、今日高亮、任务统计等功能',
          ),
          const _FeatureItem(
            icon: Icons.task_alt,
            title: '任务管理',
            description: '添加、编辑、删除任务，状态追踪',
          ),
          const _FeatureItem(
            icon: Icons.drag_indicator,
            title: '交互体验',
            description: '可拖动面板、动画效果、状态反馈',
          ),
          const SizedBox(height: 24),
          // 即将推出
          const _SectionTitle('即将推出'),
          const _FutureFeatureItem('数据同步与备份'),
          const _FutureFeatureItem('日程分类管理'),
          const _FutureFeatureItem('提醒功能'),
          const _FutureFeatureItem('日程搜索'),
          const _FutureFeatureItem('数据导入导出'),
          const _FutureFeatureItem('深色模式'),
          const _FutureFeatureItem('多语言支持'),
          const SizedBox(height: 24),
          // 开发者信息
          const _SectionTitle('开发者'),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('开源项目'),
            subtitle: const Text('欢迎贡献代码和提出建议'),
            onTap: () {
              // TODO: 打开项目地址
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ContentText extends StatelessWidget {
  final String text;

  const _ContentText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        height: 1.5,
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(description),
    );
  }
}

class _FutureFeatureItem extends StatelessWidget {
  final String feature;

  const _FutureFeatureItem(this.feature);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.upcoming),
      title: Text(feature),
      dense: true,
    );
  }
} 