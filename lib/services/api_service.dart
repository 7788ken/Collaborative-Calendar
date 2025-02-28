import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/calendar_book.dart';
import '../models/schedule_item.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3002';
  
  // 用于通用错误处理
  Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      throw Exception('API错误: ${response.statusCode} - ${response.body}');
    }
  }

  // 日历管理API
  
  // 创建共享日历并获取分享码
  Future<String> shareCalendar(CalendarBook calendar, List<ScheduleItem> schedules) async {
    // 确保日期字段被正确转换为时间戳格式
    final schedulesData = schedules.map((s) {
      final scheduleMap = s.toMap();
      
      // 验证并确保startTime和endTime是整数时间戳格式
      if (scheduleMap['start_time'] is DateTime) {
        scheduleMap['start_time'] = (scheduleMap['start_time'] as DateTime).millisecondsSinceEpoch;
      }
      
      if (scheduleMap['end_time'] is DateTime) {
        scheduleMap['end_time'] = (scheduleMap['end_time'] as DateTime).millisecondsSinceEpoch;
      }
      
      // 确保字段名称与后端API期望的一致
      final formattedMap = {
        'id': scheduleMap['id'],
        'title': scheduleMap['title'],
        'description': scheduleMap['description'],
        'startTime': scheduleMap['start_time'],
        'endTime': scheduleMap['end_time'],
        'isAllDay': scheduleMap['is_all_day'],
        'location': scheduleMap['location'],
      };
      
      return formattedMap;
    }).toList();
    
    final response = await http.post(
      Uri.parse('$baseUrl/api/calendars/share'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': calendar.name,
        'color': calendar.color.value.toRadixString(16),
        'schedules': schedulesData,
      }),
    );
    
    final data = await _handleResponse(response);
    return data['shareCode'];
  }
  
  // 获取共享日历信息
  Future<Map<String, dynamic>> getSharedCalendar(String shareCode) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/calendars/$shareCode'),
    );
    
    return await _handleResponse(response);
  }
  
  // 更新共享日历信息
  Future<void> updateSharedCalendar(String shareCode, String name, int colorValue) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/calendars/$shareCode'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'color': colorValue.toRadixString(16),
      }),
    );
    
    await _handleResponse(response);
  }
  
  // 日程管理API
  
  // 获取日历下所有日程
  Future<List<dynamic>> getSchedules(String shareCode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/calendars/$shareCode/schedules'),
      );
      
      final data = await _handleResponse(response);
      
      // 检查返回的数据格式是否正确
      if (data == null) {
        throw Exception('API返回数据为空');
      }
      
      if (!data.containsKey('schedules')) {
        // 如果返回的JSON没有schedules字段，打印数据以便调试
        print('API返回的数据不包含schedules字段: $data');
        
        // 返回空列表而不是抛出异常，避免导致整个导入流程失败
        return [];
      }
      
      // 确保schedules字段是一个列表
      final schedules = data['schedules'];
      if (schedules == null) {
        return [];
      }
      
      if (schedules is! List) {
        print('schedules字段不是列表: $schedules');
        return [];
      }
      
      return schedules;
    } catch (e) {
      print('获取日程时出错: $e');
      rethrow;
    }
  }
  
  // 添加日程
  Future<Map<String, dynamic>> addSchedule(String shareCode, ScheduleItem schedule) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/calendars/$shareCode/schedules'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(schedule.toMap()),
    );
    
    return await _handleResponse(response);
  }
  
  // 更新日程
  Future<void> updateSchedule(String shareCode, String scheduleId, ScheduleItem schedule) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/calendars/$shareCode/schedules/$scheduleId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(schedule.toMap()),
    );
    
    await _handleResponse(response);
  }
  
  // 删除日程
  Future<void> deleteSchedule(String shareCode, String scheduleId) async {
    // 服务器已经实现了软删除，使用DELETE请求时会将isDeleted字段设为true
    print('ApiService: 发送删除请求，shareCode=$shareCode, scheduleId=$scheduleId');
    final response = await http.delete(
      Uri.parse('$baseUrl/api/calendars/$shareCode/schedules/$scheduleId'),
    );
    
    print('ApiService: 删除请求响应状态: ${response.statusCode}');
    await _handleResponse(response);
    print('ApiService: 删除请求完成');
  }
  
  // 批量同步API
  
  // 批量同步日程（处理离线编辑后的同步）
  Future<Map<String, dynamic>> syncSchedules(String shareCode, List<Map<String, dynamic>> changes) async {
    try {
      print('开始同步日程到云端，分享码: $shareCode');
      print('需要同步的日程数量: ${changes.length}');
      
      // 确保日期字段被正确转换为时间戳格式
      final formattedChanges = changes.map((schedule) {
        // 复制一份数据，避免修改原始数据
        final formattedSchedule = Map<String, dynamic>.from(schedule);
        
        // 转换字段名称和格式以匹配API期望的格式
        if (formattedSchedule.containsKey('start_time')) {
          var startTime = formattedSchedule['start_time'];
          if (startTime is DateTime) {
            startTime = startTime.millisecondsSinceEpoch;
          } else if (startTime is String) {
            startTime = DateTime.parse(startTime).millisecondsSinceEpoch;
          }
          formattedSchedule['startTime'] = startTime;
          formattedSchedule.remove('start_time');
        }
        
        if (formattedSchedule.containsKey('end_time')) {
          var endTime = formattedSchedule['end_time'];
          if (endTime is DateTime) {
            endTime = endTime.millisecondsSinceEpoch;
          } else if (endTime is String) {
            endTime = DateTime.parse(endTime).millisecondsSinceEpoch;
          }
          formattedSchedule['endTime'] = endTime;
          formattedSchedule.remove('end_time');
        }
        
        if (formattedSchedule.containsKey('is_all_day')) {
          formattedSchedule['isAllDay'] = formattedSchedule['is_all_day'];
          formattedSchedule.remove('is_all_day');
        }
        
        // 添加任务完成状态处理 - 确保使用isCompleted字段
        if (formattedSchedule.containsKey('is_completed')) {
          formattedSchedule['isCompleted'] = formattedSchedule['is_completed'];
          formattedSchedule.remove('is_completed');
        }
        
        // 确保isCompleted是整数格式 (0或1)，而不是布尔值
        if (formattedSchedule.containsKey('isCompleted') && formattedSchedule['isCompleted'] is bool) {
          formattedSchedule['isCompleted'] = formattedSchedule['isCompleted'] ? 1 : 0;
        }
        
        // 处理软删除标记
        if (formattedSchedule.containsKey('is_deleted')) {
          // 保留is_deleted字段，确保它是整数类型（0或1）
          if (formattedSchedule['is_deleted'] is bool) {
            formattedSchedule['is_deleted'] = formattedSchedule['is_deleted'] ? 1 : 0;
          }
        }
        
        if (formattedSchedule.containsKey('calendar_id')) {
          formattedSchedule.remove('calendar_id'); // 服务器端不需要此字段
        }
        
        // 如果缺少id字段，添加一个随机UUID
        if (!formattedSchedule.containsKey('id') || formattedSchedule['id'] == null) {
          formattedSchedule['id'] = DateTime.now().millisecondsSinceEpoch.toString();
        }
        
        print('格式化后的日程: $formattedSchedule');
        return formattedSchedule;
      }).toList();
      
      print('准备发送同步请求到服务器');
      final response = await http.post(
        Uri.parse('$baseUrl/api/calendars/$shareCode/sync'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'changes': formattedChanges}),
      );
      
      print('服务器响应状态码: ${response.statusCode}');
      print('服务器响应内容: ${response.body}');
      
      final result = await _handleResponse(response);
      print('同步完成，服务器返回: $result');
      return result;
    } catch (e) {
      print('同步日程时出错: $e');
      rethrow;
    }
  }
} 