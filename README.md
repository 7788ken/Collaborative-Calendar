# Flutter JTRL应用程序

/* 不准你修改 */
在当今数字化时代，日程管理对于家庭生活的有序运行至关重要。然而，现有的 Google 日历以及手机自带日历，在面对家庭日常日程安排时，暴露出了明显的不足。其中最为突出的问题便是缺乏有效的分享和协作功能，这使得家庭成员之间难以高效地协调日程，导致家庭日程管理陷入困境。比如，家中老人的就医、社交活动等日程安排，以及小朋友的学习课程、兴趣班时间，常常会因为缺乏协同管理而出现冲突或者遗漏，不仅给家人带来诸多不便，也影响了家庭生活的和谐与高效。
为了彻底解决这些痛点，我们精心打造了一款基于 Flutter 开发的多功能移动应用程序。这款应用专注于提供高效的任务管理和资源调度功能，旨在成为家庭日程管理的得力助手。通过它，家庭成员可以轻松地共享日程信息，实时了解彼此的安排，方便进行合理的规划和调整。无论是日常的家务分配、接送孩子，还是重要的家庭聚会、外出旅行计划，都能通过该应用有条不紊地进行安排。它不仅可以帮助您轻松协调家庭日程，避免冲突和遗漏，还能让您在家庭生活中真正成为掌控时间的 "时间管理大师"，提升家庭生活的质量和效率。

## 项目描述

JTRL（Just-in-Time Resource Locator）是一款跨平台移动应用，旨在帮助用户高效地管理任务、资源和日程安排。该应用采用Flutter框架开发，确保在iOS和Android平台上都能提供流畅的用户体验。

## 功能特点

- 任务管理与跟踪
- 资源分配与调度
- 实时通知与提醒
- 数据同步与云存储
- 用户友好的界面设计
- 多语言支持

## 技术栈

- Flutter: 用于构建跨平台UI
- Dart: 主要编程语言
- Provider: 状态管理
- Firebase: 后端服务与数据存储
- SQLite: 本地数据存储

## 开始使用

### 先决条件

- Flutter SDK (最新版本)
- Dart SDK
- Android Studio 或 VS Code
- iOS开发需要Mac和Xcode

### 安装

1. 克隆仓库
```
git clone https://github.com/yourusername/flutter_jtrl.git
```

2. 安装依赖
```
cd flutter_jtrl
flutter pub get
```

3. 运行应用
```
flutter run
```

## 项目结构

```
flutter_jtrl/
├── lib/               # 源代码
│   ├── models/        # 数据模型
│   ├── screens/       # UI界面
│   ├── services/      # 业务逻辑
│   ├── utils/         # 工具类
│   └── main.dart      # 应用入口
├── assets/            # 静态资源
├── test/              # 测试文件
└── pubspec.yaml       # 项目配置
```

## 贡献指南

如果您想为项目做出贡献，请遵循以下步骤：

1. Fork本仓库
2. 创建您的特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交您的更改 (`git commit -m '添加一些惊人的特性'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启一个Pull Request

## 待办事项

- 完善用户认证系统
- 添加离线模式支持
- 优化应用性能
- 增加数据可视化功能

## 最新功能更新

### 已完成功能

1. **任务完成状态持久化**
   - 引入 `shared_preferences` 依赖，实现任务完成状态的本地存储
   - 应用重启后可保持任务完成状态不丢失

2. **任务项组件改进**
   - 优化 `TaskItemWidget` 界面设计，提供更清晰的视觉层次
   - 实现滑动操作菜单，支持编辑和删除任务
   - 添加任务完成状态切换动画和视觉反馈
   - 完成状态切换时添加触觉反馈，提升用户体验

3. **日历视图功能增强**
   - 日历格子现在显示已完成任务的数量而非总任务数
   - 优化日期选择和月份切换逻辑
   - 增强日历与任务面板的交互体验

4. **数据管理优化**
   - 实现 `ScheduleData` 类管理任务数据和完成状态
   - 添加任务数据迁移支持，确保数据模型变更时的平滑过渡
   - 提高数据加载和状态更新的效率

5. **UI/UX 改进**
   - 实现可拖拽滚动面板，优化日历和任务列表之间的切换体验
   - 添加空状态提示，当无任务时给予用户明确引导
   - 完善主题色应用和字体大小调整功能

### 待办事项

1. **多设备同步**
   - 实现云端同步功能，使用户可以在多个设备间同步任务和日历
   - 添加离线模式和冲突解决机制

2. **重复任务支持**
   - 设计并实现重复任务功能，支持每日、每周、每月、自定义重复
   - 提供重复任务的完成状态管理，区分单次完成和周期性完成

3. **任务提醒功能**
   - 集成本地通知系统，支持任务到期提醒
   - 实现可自定义的提醒时间选项

4. **任务分类与标签**
   - 添加任务分类系统，允许用户对任务进行分组
   - 实现任务标签功能，支持多标签筛选和管理

5. **数据导出与备份**
   - 设计任务数据的导出功能，支持导出为常见格式
   - 提供手动备份和自动备份选项

6. **性能优化**
   - 优化大量任务情况下的加载和渲染性能
   - 实现任务数据的分页加载机制

7. **用户体验改进**
   - 支持长按任务进行拖拽排序
   - 实现批量操作功能（批量删除、标记完成等）
   - 添加任务搜索功能

8. **统计与分析**
   - 设计任务完成情况的统计视图
   - 实现任务趋势分析，帮助用户了解自己的任务管理效率

## 更新日志

### 2024-06-19（PM：AI 出现了幻觉）
- 实现了任务完成状态的持久化存储
- 优化了任务项组件UI和交互体验
- 改进了日历视图，显示已完成任务数量
- 添加了数据管理优化和状态更新机制
- 更新了 `shared_preferences` 依赖

### 2024-02-26
- 实现了右上角按钮功能
- 添加了日程页面的功能
- 优化了用户界面交互体验

### 2024-02-25
- 添加了日程备注字段
- 优化了日程项的显示样式
- 实现了任务界面的日程分组显示

## 待实现功能
- [x] 数据持久化存储
- [x] 添加/编辑/删除日程
- [ ] 日程分类管理
- [ ] 提醒功能
- [ ] 日程搜索
- [ ] 数据导入导出
- [ ] 深色模式支持
- [ ] 多语言支持

## 未来计划

- 集成第三方API
- 开发Web版本
- 添加高级分析功能
- 扩展国际化支持

## 许可证

本项目基于MIT许可证 - 详见 LICENSE 文件

## 联系方式

项目维护者 - email@example.com

项目链接: [https://github.com/yourusername/flutter_jtrl](https://github.com/yourusername/flutter_jtrl)

## 技术细节

### 使用的 Flutter 组件
- DraggableScrollableSheet：实现可拖动面板
- SingleChildScrollView：处理面板内容滚动
- GridView：实现日历网格
- ListView：显示日程列表
- IntrinsicHeight：确保行程项布局一致
- AnimatedContainer：实现平滑动画

### 状态管理
- 使用 StatefulWidget 管理组件状态
- 实现日程完成状态的切换
- 日历和日程列表状态同步

### 布局实现
- 使用 Stack 布局实现日历和可拖动面板的叠加
- 使用 Row 和 Column 布局实现日程项的结构
- 使用 BoxDecoration 实现边框和阴影效果

### 交互设计
- 拖动指示器区域带有分隔线
- 面板顶部阴影效果
- 可拖动区域的吸附效果
- 日期选择时的面板重置
