import 'database/database_helper.dart';
import '../models/task_item.dart';

class TaskService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // 获取特定日历本的所有任务
  Future<List<TaskItem>> getTasks(String calendarId) async {
    return await _dbHelper.getTasks(calendarId);
  }

  // 获取特定日历本的所有未完成任务
  Future<List<TaskItem>> getIncompleteTasks(String calendarId) async {
    final tasks = await _dbHelper.getTasks(calendarId);
    return tasks.where((task) => !task.isCompleted).toList();
  }

  // 获取特定日历本的所有已完成任务
  Future<List<TaskItem>> getCompletedTasks(String calendarId) async {
    final tasks = await _dbHelper.getTasks(calendarId);
    return tasks.where((task) => task.isCompleted).toList();
  }

  // 添加任务
  Future<void> addTask(TaskItem task) async {
    await _dbHelper.insertTask(task);
  }

  // 更新任务
  Future<void> updateTask(TaskItem task) async {
    await _dbHelper.updateTask(task);
  }

  // 切换任务完成状态
  Future<void> toggleTaskComplete(String taskId) async {
    final tasks = await _dbHelper.getTasks('');
    final task = tasks.firstWhere((t) => t.id == taskId);
    await _dbHelper.updateTask(task.toggleComplete());
  }

  // 删除任务
  Future<void> deleteTask(String id) async {
    await _dbHelper.deleteTask(id);
  }
} 