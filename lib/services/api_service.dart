import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/calendar_book.dart';
import '../models/schedule_item.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3002';
  static const Duration defaultTimeout = Duration(seconds: 10); // 默认10秒超时
  static const int maxRetries = 3; // 最大重试次数
  
  // 用于通用错误处理
  Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      throw Exception('API错误: ${response.statusCode} - ${response.body}');
    }
  }
  
  // 带有重试机制的HTTP请求函数
  Future<http.Response> _makeRequestWithRetry({
    required Future<http.Response> Function() requestFunc,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;
    
    while (true) {
      attempts++;
      try {
        final response = await requestFunc().timeout(defaultTimeout);
        return response;
      } catch (e) {
        // 如果达到最大重试次数，则抛出异常
        if (attempts >= maxRetries) {
          debugPrint('请求失败，已达到最大重试次数: $attempts');
          if (e is TimeoutException) {
            throw Exception('请求超时，所有重试均失败: $e');
          } else if (e is SocketException) {
            throw Exception('网络连接错误，所有重试均失败: $e');
          } else if (e is HttpException) {
            throw Exception('HTTP请求错误，所有重试均失败: $e');
          } else {
            throw Exception('请求失败，所有重试均失败: $e');
          }
        }
        
        // 根据错误类型决定是否重试
        if (e is TimeoutException) {
          debugPrint('请求超时，将在${retryDelay.inSeconds}秒后重试 (尝试 $attempts/$maxRetries)');
          await Future.delayed(retryDelay);
          continue;
        } else if (e is SocketException) {
          debugPrint('网络连接错误，将在${retryDelay.inSeconds}秒后重试 (尝试 $attempts/$maxRetries)');
          await Future.delayed(retryDelay);
          continue;
        } else if (e is HttpException) {
          debugPrint('HTTP请求错误，将在${retryDelay.inSeconds}秒后重试 (尝试 $attempts/$maxRetries)');
          await Future.delayed(retryDelay);
          continue;
        } else {
          // 对于其他类型的错误，记录后重试
          debugPrint('未知错误类型，将在${retryDelay.inSeconds}秒后重试 (尝试 $attempts/$maxRetries): $e');
          await Future.delayed(retryDelay);
          continue;
        }
      }
    }
  }

  // 日历管理API
  
  // 创建共享日历并获取分享码
  Future<String> shareCalendar(CalendarBook calendar, List<ScheduleItem> schedules) async {
    try {
      debugPrint('开始共享日历: ${calendar.name}');
      // 确保日期字段被正确转换为毫秒时间戳格式
      final schedulesData = schedules.map((s) {
        debugPrint('处理日程: ${s.title}');
        
        // 将日期转换为毫秒时间戳
        final startTimeMs = s.startTime.millisecondsSinceEpoch;
        final endTimeMs = s.endTime.millisecondsSinceEpoch;
        
        debugPrint('转换后的开始时间(时间戳): $startTimeMs');
        debugPrint('转换后的结束时间(时间戳): $endTimeMs');
        
        // 使用服务器期望的字段名称和格式
        final formattedMap = {
          'id': s.id,
          'title': s.title,
          'description': s.description ?? '',
          'startTime': startTimeMs, // 使用毫秒时间戳
          'endTime': endTimeMs, // 使用毫秒时间戳
          'isAllDay': s.isAllDay ? 1 : 0,
          'location': s.location ?? '',
          'isCompleted': s.isCompleted ? 1 : 0,
        };
        
        return formattedMap;
      }).toList();
      
      debugPrint('准备发送${schedulesData.length}个日程到服务器');
      
      // 记录格式化后的第一个日程以便调试
      if (schedulesData.isNotEmpty) {
        debugPrint('格式化后的第一个日程示例: ${schedulesData.first}');
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/calendars/share'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': calendar.name,
          'color': calendar.color.value.toRadixString(16),
          'schedules': schedulesData,
        }),
      );
      
      debugPrint('服务器响应状态码: ${response.statusCode}');
      
      if (response.statusCode >= 400) {
        debugPrint('服务器返回错误: ${response.statusCode} - ${response.body}');
        throw Exception('服务器返回错误: ${response.statusCode}');
      }
      
      final data = await _handleResponse(response);
      debugPrint('共享成功，获取到分享码: ${data['shareCode']}');
      return data['shareCode'];
    } catch (e) {
      debugPrint('共享日历失败: $e');
      rethrow;
    }
  }
  
  // 获取共享日历信息
  Future<Map<String, dynamic>> getSharedCalendar(String shareCode) async {
    try {
      debugPrint('开始获取共享日历信息，分享码: $shareCode');
      
      // Map<String, dynamic> fallbackResponse = {
      //   'name': '导入失败的日历',
      //   'color': Colors.grey.value.toRadixString(16), 
      //   'error': '无法获取日历信息'
      // };
      
      try {
        final response = await _makeRequestWithRetry(
          requestFunc: () => http.get(
            Uri.parse('$baseUrl/api/calendars/$shareCode'),
          ),
        );
        
        debugPrint('服务器响应状态码: ${response.statusCode}');
        
        // 检查HTTP状态码
        if (response.statusCode < 200 || response.statusCode >= 300) {
          debugPrint('服务器返回错误状态码: ${response.statusCode}');
          fallbackResponse['error'] = '服务器返回错误状态码: ${response.statusCode}';
          return fallbackResponse;
        }
        
        // 检查响应体是否为空
        if (response.body.isEmpty) {
          debugPrint('服务器返回空响应');
          fallbackResponse['error'] = '服务器返回空响应';
          return fallbackResponse;
        }
        
        // 记录原始响应内容用于调试
        debugPrint('服务器响应内容: ${response.body}');
        
        // 尝试解析JSON响应
        Map<String, dynamic> data;
        try {
          data = json.decode(response.body);
        } catch (e) {
          debugPrint('解析JSON出错: $e');
          fallbackResponse['error'] = '解析服务器响应失败: $e';
          return fallbackResponse;
        }
        
        // 服务器可能返回错误信息
        if (data.containsKey('error')) {
          debugPrint('服务器返回错误信息: ${data['error']}');
          fallbackResponse['error'] = '服务器错误: ${data['error']}';
          return fallbackResponse;
        }
        
        // 检查服务器返回的数据结构
        if (data.containsKey('calendar')) {
          // 如果包含calendar字段，可能是嵌套对象
          final calendarData = data['calendar'];
          if (calendarData is Map<String, dynamic>) {
            debugPrint('从calendar字段提取数据');
            return calendarData;
          } else {
            debugPrint('calendar字段不是有效的对象: $calendarData');
            fallbackResponse['error'] = 'calendar字段格式无效';
            return fallbackResponse;
          }
        } else if (data.containsKey('name') && data.containsKey('color')) {
          // 直接返回了日历对象
          debugPrint('服务器直接返回了日历数据');
          return data;
        } else {
          // 缺少必要字段
          debugPrint('API返回的数据不符合预期: $data');
          fallbackResponse['error'] = '返回数据缺少必要字段';
          // 检查是否有可用信息可以提取
          if (data.containsKey('name')) {
            fallbackResponse['name'] = data['name'];
          }
          if (data.containsKey('color')) {
            fallbackResponse['color'] = data['color'];
          }
          return fallbackResponse;
        }
      } catch (e) {
        debugPrint('获取共享日历过程中出错: $e');
        fallbackResponse['error'] = '获取日历信息失败: $e';
        return fallbackResponse;
      }
    } catch (e) {
      // 最外层的错误处理，确保永远不会抛出未捕获的异常
      debugPrint('获取共享日历过程中发生严重错误: $e');
      return {
        'name': '错误',
        'color': Colors.red.value.toRadixString(16),
        'error': '严重错误: $e'
      };
    }
  }
  
  // 获取日历最后更新时间
  Future<DateTime?> getCalendarLastUpdateTime(String shareCode) async {
    try {
      debugPrint('开始获取日历最后更新时间，分享码: $shareCode');
      
      Map<String, dynamic> calendarInfo;
      try {
        calendarInfo = await getSharedCalendar(shareCode);
        debugPrint('获取到日历信息: $calendarInfo');
        
        // 检查是否有错误
        if (calendarInfo.containsKey('error')) {
          debugPrint('获取日历信息时发生错误: ${calendarInfo['error']}');
          return null;
        }
      } catch (e) {
        debugPrint('获取日历信息失败: $e');
        return null;
      }
      
      // 尝试获取最后更新时间
      // 查找可能的字段名称：lastUpdatedAt, updatedAt, lastModified 等
      final possibleFieldNames = ['lastUpdatedAt', 'updatedAt', 'lastModified', 'modified_at'];
      dynamic timestamp;
      
      // 尝试找到时间戳字段
      for (final fieldName in possibleFieldNames) {
        if (calendarInfo.containsKey(fieldName) && calendarInfo[fieldName] != null) {
          timestamp = calendarInfo[fieldName];
          debugPrint('找到时间戳字段 $fieldName: $timestamp (类型: ${timestamp.runtimeType})');
          break;
        }
      }
      
      if (timestamp == null) {
        debugPrint('在日历信息中未找到有效的时间戳字段');
        return null;
      }
      
      // 根据类型处理时间戳
      if (timestamp is int) {
        // 整数时间戳
        DateTime result;
        try {
          result = DateTime.fromMillisecondsSinceEpoch(timestamp);
          debugPrint('成功将整数时间戳解析为日期时间: $result');
          return result;
        } catch (e) {
          debugPrint('解析整数时间戳失败: $e');
          return null;
        }
      } else if (timestamp is String) {
        // 字符串时间戳，可能是ISO格式或毫秒数
        try {
          // 首先尝试作为ISO字符串解析
          final result = DateTime.parse(timestamp);
          debugPrint('成功将字符串解析为ISO日期时间: $result');
          return result;
        } catch (parseError) {
          debugPrint('无法作为ISO字符串解析: $parseError');
          
          // 尝试作为毫秒数解析
          try {
            final millis = int.parse(timestamp);
            final result = DateTime.fromMillisecondsSinceEpoch(millis);
            debugPrint('成功将字符串解析为毫秒时间戳: $result');
            return result;
          } catch (millisError) {
            debugPrint('无法将字符串解析为毫秒时间戳: $millisError');
            return null;
          }
        }
      } else {
        debugPrint('未知的时间戳类型: ${timestamp.runtimeType}');
        return null;
      }
    } catch (e) {
      // 捕获所有异常，确保不会抛出未处理的错误
      debugPrint('获取日历最后更新时间时发生未预期的错误: $e');
      return null;
    }
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
      debugPrint('开始获取日历日程，分享码: $shareCode');
      
      final Uri uri = Uri.parse('$baseUrl/api/calendars/$shareCode/schedules');
      debugPrint('请求URL: $uri');
      
      // 发送请求前向服务器提示正确的日期格式
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Date-Format': 'timestamp' // 告诉服务器我们期望timestamp格式
      };
      
      final response = await _makeRequestWithRetry(
        requestFunc: () => http.get(uri, headers: headers),
      );
      
      debugPrint('服务器响应状态码: ${response.statusCode}');
      
      // 处理服务器错误
      if (response.statusCode >= 400) {
        debugPrint('服务器返回错误: ${response.statusCode} - ${response.body}');
        throw Exception('服务器返回错误: ${response.statusCode}');
      }
      
      // 记录原始响应内容用于调试
      debugPrint('服务器响应内容: ${response.body}');
      
      // 尝试解析响应数据
      try {
        final dynamic data = json.decode(response.body);
        
        if (data == null) {
          debugPrint('API返回数据为空');
          return [];
        }
        
        // 检查返回的数据格式
        if (data is Map) {
          // 如果是Map，查找schedules字段
          if (data.containsKey('schedules')) {
            final schedules = data['schedules'];
            if (schedules == null) {
              debugPrint('schedules字段为null');
              return [];
            }
            
            if (schedules is! List) {
              debugPrint('schedules字段不是列表: $schedules');
              return [];
            }
            
            debugPrint('成功获取到 ${schedules.length} 个日程');
            
            // 确保返回的日程格式正确
            List<dynamic> processedSchedules = schedules.map((schedule) {
              // 打印每个日程的startTime和endTime类型
              debugPrint('Schedule ${schedule['id']} startTime type: ${schedule['startTime'].runtimeType}');
              debugPrint('Schedule ${schedule['id']} endTime type: ${schedule['endTime'].runtimeType}');
              
              // 确保startTime和endTime是整数时间戳格式
              var startTime = schedule['startTime'];
              var endTime = schedule['endTime'];
              
              // 如果服务器返回的是JavaScript Date.getTime()结果，应该直接是数字
              // 不需要特殊处理，但为了健壮性，我们检查一下
              if (startTime is! int) {
                debugPrint('警告: startTime不是整数: $startTime');
                // 尝试转换为整数
                if (startTime is String) {
                  try {
                    startTime = int.parse(startTime);
                  } catch (e) {
                    debugPrint('无法将startTime解析为整数: $e');
                    // 使用当前时间作为后备
                    startTime = DateTime.now().millisecondsSinceEpoch;
                  }
                }
              }
              
              if (endTime is! int) {
                debugPrint('警告: endTime不是整数: $endTime');
                // 尝试转换为整数
                if (endTime is String) {
                  try {
                    endTime = int.parse(endTime);
                  } catch (e) {
                    debugPrint('无法将endTime解析为整数: $e');
                    // 使用当前时间作为后备
                    endTime = DateTime.now().millisecondsSinceEpoch;
                  }
                }
              }
              
              // 返回处理后的日程
              return {
                ...schedule,
                'startTime': startTime,
                'endTime': endTime
              };
            }).toList();
            
            return processedSchedules;
          } else if (data.containsKey('success') && data['success'] == false) {
            // 处理明确的错误响应
            debugPrint('服务器返回错误: ${data['message']}');
            throw Exception('API错误: ${data['message']}');
          } else {
            // 返回空列表
            debugPrint('API返回的数据不包含schedules字段: $data');
            return [];
          }
        } else if (data is List) {
          // 如果直接返回日程列表
          debugPrint('服务器直接返回了日程列表，数量: ${data.length}');
          return data;
        } else {
          debugPrint('无法识别的响应数据格式: $data');
          return [];
        }
      } catch (e) {
        debugPrint('解析服务器响应时出错: $e');
        rethrow;
      }
    } catch (e) {
      debugPrint('获取日程时出错: $e');
      rethrow;
    }
  }
  
  // 添加日程
  Future<Map<String, dynamic>> addSchedule(String shareCode, ScheduleItem schedule) async {
    try {
      debugPrint('ApiService: 开始添加日程，shareCode=$shareCode, title=${schedule.title}');
      
      // 准备要发送的数据，确保日期使用毫秒时间戳格式
      final Map<String, dynamic> scheduleData = {
        'id': schedule.id,
        'title': schedule.title,
        'description': schedule.description ?? '',
        'location': schedule.location ?? '',
        'startTime': schedule.startTime.millisecondsSinceEpoch, // 使用毫秒时间戳
        'endTime': schedule.endTime.millisecondsSinceEpoch, // 使用毫秒时间戳
        'isAllDay': schedule.isAllDay ? 1 : 0,
        'isCompleted': schedule.isCompleted ? 1 : 0
      };
      
      debugPrint('ApiService: 准备发送的数据: $scheduleData');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/calendars/$shareCode/schedules'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(scheduleData),
      );
      
      debugPrint('ApiService: 添加请求响应状态: ${response.statusCode}');
      
      if (response.statusCode >= 400) {
        debugPrint('ApiService: 添加请求失败，状态码: ${response.statusCode}, 内容: ${response.body}');
        throw Exception('添加日程失败: ${response.statusCode}');
      }
      
      final data = await _handleResponse(response);
      debugPrint('ApiService: 添加请求完成，返回数据: $data');
      return data;
    } catch (e) {
      debugPrint('ApiService: 添加日程时出错: $e');
      rethrow;
    }
  }
  
  // 更新日程
  Future<void> updateSchedule(String shareCode, String scheduleId, ScheduleItem schedule) async {
    try {
      debugPrint('ApiService: 开始更新日程，shareCode=$shareCode, scheduleId=$scheduleId');
      
      // 准备请求数据，确保字段名称和格式与API期望的一致
      // 使用毫秒时间戳格式
      final Map<String, dynamic> scheduleData = {
        'id': schedule.id,
        'title': schedule.title,
        'description': schedule.description ?? '',
        'location': schedule.location ?? '',
        'startTime': schedule.startTime.millisecondsSinceEpoch, // 使用毫秒时间戳
        'endTime': schedule.endTime.millisecondsSinceEpoch, // 使用毫秒时间戳
        'isAllDay': schedule.isAllDay ? 1 : 0,
        'isCompleted': schedule.isCompleted ? 1 : 0
      };
      
      debugPrint('ApiService: 准备发送的数据: $scheduleData');
      
      final response = await http.put(
        Uri.parse('$baseUrl/api/calendars/$shareCode/schedules/$scheduleId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(scheduleData),
      );
      
      debugPrint('ApiService: 更新请求响应状态: ${response.statusCode}');
      
      if (response.statusCode >= 400) {
        debugPrint('ApiService: 更新请求失败，状态码: ${response.statusCode}, 内容: ${response.body}');
        throw Exception('更新日程失败: ${response.statusCode}');
      }
      
      await _handleResponse(response);
      debugPrint('ApiService: 更新请求完成');
    } catch (e) {
      debugPrint('ApiService: 更新日程时出错: $e');
      rethrow;
    }
  }
  
  // 删除日程
  Future<void> deleteSchedule(String shareCode, String scheduleId) async {
    try {
      // 服务器已经实现了软删除，使用DELETE请求时会将isDeleted字段设为true
      debugPrint('ApiService: 发送删除请求，shareCode=$shareCode, scheduleId=$scheduleId');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/api/calendars/$shareCode/schedules/$scheduleId'),
      );
      
      debugPrint('ApiService: 删除请求响应状态: ${response.statusCode}');
      
      if (response.statusCode >= 400) {
        debugPrint('ApiService: 删除请求失败，状态码: ${response.statusCode}, 内容: ${response.body}');
        throw Exception('删除日程失败: ${response.statusCode}');
      }
      
      await _handleResponse(response);
      debugPrint('ApiService: 删除请求完成');
    } catch (e) {
      debugPrint('ApiService: 删除日程时出错: $e');
      rethrow;
    }
  }
  
  // 批量同步API
  
  // 批量同步日程（处理离线编辑后的同步）
  Future<Map<String, dynamic>> syncSchedules(String shareCode, List<Map<String, dynamic>> changes) async {
    try {
      debugPrint('开始同步日程到云端，分享码: $shareCode');
      debugPrint('需要同步的日程数量: ${changes.length}');
      
      // 防御性检查输入参数
      if (shareCode.isEmpty) {
        debugPrint('错误: 分享码为空');
        return <String, dynamic>{'success': false, 'message': '分享码不能为空', 'changes': []};
      }
      
      if (changes.isEmpty) {
        debugPrint('没有需要同步的更改，直接返回');
        return <String, dynamic>{'success': true, 'message': '没有需要同步的更改', 'changes': []};
      }
      
      // 确保日期字段被正确转换为毫秒时间戳格式 (JavaScript更容易处理)
      final List<Map<String, dynamic>> formattedChanges = [];
      
      try {
        for (var schedule in changes) {
          // 跳过null或无效的日程
          if (schedule == null) {
            debugPrint('警告: 发现null日程，已跳过');
            continue;
          }
          
          // 复制一份数据，避免修改原始数据
          final formattedSchedule = Map<String, dynamic>.from(schedule);
          
          // 记录处理的日程信息
          final String scheduleTitle = formattedSchedule['title'] ?? '无标题';
          debugPrint('处理日程: $scheduleTitle (ID: ${formattedSchedule['id'] ?? '无ID'})');
          
          // 安全地处理开始时间
          try {
            if (formattedSchedule.containsKey('start_time') || formattedSchedule.containsKey('startTime')) {
              var startTime;
              
              // 获取开始时间，无论它使用哪个字段名
              if (formattedSchedule.containsKey('start_time')) {
                startTime = formattedSchedule['start_time'];
                formattedSchedule.remove('start_time');
              } else {
                startTime = formattedSchedule['startTime'];
              }
              
              // 将开始时间转换为毫秒时间戳
              int startTimeMs;
              if (startTime == null) {
                debugPrint('警告: 日程 "$scheduleTitle" 的开始时间为null，使用当前时间');
                startTimeMs = DateTime.now().millisecondsSinceEpoch;
              } else if (startTime is DateTime) {
                startTimeMs = startTime.millisecondsSinceEpoch;
              } else if (startTime is int) {
                startTimeMs = startTime; // 已经是时间戳
              } else if (startTime is String) {
                // 如果是字符串，尝试解析为DateTime
                try {
                  startTimeMs = DateTime.parse(startTime).millisecondsSinceEpoch;
                } catch (e) {
                  debugPrint('无法解析开始时间字符串: $startTime, 错误: $e');
                  // 使用当前时间作为后备
                  startTimeMs = DateTime.now().millisecondsSinceEpoch;
                }
              } else {
                debugPrint('警告: 无法处理的开始时间类型: ${startTime.runtimeType}');
                // 使用当前时间作为后备
                startTimeMs = DateTime.now().millisecondsSinceEpoch;
              }
              
              // 设置处理后的开始时间为时间戳
              formattedSchedule['startTime'] = startTimeMs;
              debugPrint('转换后的开始时间(时间戳): $startTimeMs');
            } else {
              // 开始时间字段不存在，使用当前时间
              debugPrint('警告: 日程 "$scheduleTitle" 缺少开始时间字段，使用当前时间');
              formattedSchedule['startTime'] = DateTime.now().millisecondsSinceEpoch;
            }
          } catch (e) {
            debugPrint('处理开始时间时出错: $e, 使用当前时间作为后备');
            formattedSchedule['startTime'] = DateTime.now().millisecondsSinceEpoch;
          }
          
          // 安全地处理结束时间
          try {
            if (formattedSchedule.containsKey('end_time') || formattedSchedule.containsKey('endTime')) {
              var endTime;
              
              // 获取结束时间，无论它使用哪个字段名
              if (formattedSchedule.containsKey('end_time')) {
                endTime = formattedSchedule['end_time'];
                formattedSchedule.remove('end_time');
              } else {
                endTime = formattedSchedule['endTime'];
              }
              
              // 将结束时间转换为毫秒时间戳
              int endTimeMs;
              if (endTime == null) {
                debugPrint('警告: 日程 "$scheduleTitle" 的结束时间为null，使用开始时间加一小时');
                // 使用开始时间 + 1小时作为默认结束时间
                final startTime = formattedSchedule['startTime'] as int;
                endTimeMs = startTime + (60 * 60 * 1000); // 一小时的毫秒数
              } else if (endTime is DateTime) {
                endTimeMs = endTime.millisecondsSinceEpoch;
              } else if (endTime is int) {
                endTimeMs = endTime; // 已经是时间戳
              } else if (endTime is String) {
                try {
                  endTimeMs = DateTime.parse(endTime).millisecondsSinceEpoch;
                } catch (e) {
                  debugPrint('无法解析结束时间字符串: $endTime, 错误: $e');
                  // 使用开始时间 + 1小时作为默认结束时间
                  final startTime = formattedSchedule['startTime'] as int;
                  endTimeMs = startTime + (60 * 60 * 1000);
                }
              } else {
                debugPrint('警告: 无法处理的结束时间类型: ${endTime.runtimeType}');
                // 使用开始时间 + 1小时作为默认结束时间
                final startTime = formattedSchedule['startTime'] as int;
                endTimeMs = startTime + (60 * 60 * 1000);
              }
              
              // 设置处理后的结束时间为时间戳
              formattedSchedule['endTime'] = endTimeMs;
              debugPrint('转换后的结束时间(时间戳): $endTimeMs');
            } else {
              // 结束时间字段不存在，使用开始时间 + 1小时
              debugPrint('警告: 日程 "$scheduleTitle" 缺少结束时间字段，使用开始时间加一小时');
              final startTime = formattedSchedule['startTime'] as int;
              formattedSchedule['endTime'] = startTime + (60 * 60 * 1000);
            }
          } catch (e) {
            debugPrint('处理结束时间时出错: $e, 使用开始时间加一小时作为后备');
            try {
              final startTime = formattedSchedule['startTime'] as int;
              formattedSchedule['endTime'] = startTime + (60 * 60 * 1000);
            } catch (e2) {
              // 保底方案：使用当前时间加一小时
              formattedSchedule['endTime'] = DateTime.now().millisecondsSinceEpoch + (60 * 60 * 1000);
            }
          }
          
          // 安全地处理其他字段
          try {
            // 处理其他字段名称的统一
            if (formattedSchedule.containsKey('is_all_day')) {
              formattedSchedule['isAllDay'] = formattedSchedule['is_all_day'] == true ? 1 : 0;
              formattedSchedule.remove('is_all_day');
            } else if (formattedSchedule.containsKey('isAllDay')) {
              // 确保isAllDay是数字格式(0或1)
              formattedSchedule['isAllDay'] = formattedSchedule['isAllDay'] == true ? 1 : 0;
            } else {
              // 默认为非全天事件
              formattedSchedule['isAllDay'] = 0;
            }
            
            // 处理完成状态
            if (formattedSchedule.containsKey('is_completed')) {
              formattedSchedule['isCompleted'] = formattedSchedule['is_completed'] == true ? 1 : 0;
              formattedSchedule.remove('is_completed');
            } else if (formattedSchedule.containsKey('isCompleted')) {
              // 确保isCompleted是数字格式(0或1)
              formattedSchedule['isCompleted'] = formattedSchedule['isCompleted'] == true ? 1 : 0;
            } else {
              // 默认为未完成
              formattedSchedule['isCompleted'] = 0;
            }
            
            // 处理软删除标记
            if (formattedSchedule.containsKey('is_deleted')) {
              formattedSchedule['is_deleted'] = formattedSchedule['is_deleted'] == true ? 1 : 0;
            }
            
            // 服务器不需要calendar_id字段
            if (formattedSchedule.containsKey('calendar_id')) {
              formattedSchedule.remove('calendar_id');
            }
            
            // 确保有ID字段
            if (!formattedSchedule.containsKey('id') || formattedSchedule['id'] == null) {
              formattedSchedule['id'] = DateTime.now().millisecondsSinceEpoch.toString();
              debugPrint('为日程创建了新ID: ${formattedSchedule['id']}');
            }
          } catch (e) {
            debugPrint('处理其他字段时出错: $e');
            // 继续处理，不中断整个流程
          }
          
          // 添加处理后的日程到列表
          formattedChanges.add(formattedSchedule);
        }
      } catch (e) {
        debugPrint('处理日程列表时发生严重错误: $e');
        // 如果有部分成功处理的日程，我们仍然尝试同步这些日程
        if (formattedChanges.isEmpty) {
          return <String, dynamic>{'success': false, 'message': '处理日程数据时出错: $e', 'changes': []};
        }
        debugPrint('将尝试同步 ${formattedChanges.length} 个已成功处理的日程');
      }
      
      debugPrint('准备发送同步请求，成功格式化 ${formattedChanges.length} 个日程');
      
      // 记录格式化后的第一个日程以便调试
      if (formattedChanges.isNotEmpty) {
        debugPrint('格式化后的第一个日程示例: ${formattedChanges.first}');
      }
      
      // 防御性网络请求处理
      try {
        debugPrint('向服务器发送同步请求...');
        final response = await http.post(
          Uri.parse('$baseUrl/api/calendars/$shareCode/sync'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'changes': formattedChanges}),
        ).timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            debugPrint('同步请求超时');
            throw TimeoutException('同步请求超时');
          },
        );
        
        debugPrint('服务器响应状态码: ${response.statusCode}');
        
        if (response.statusCode >= 400) {
          debugPrint('服务器返回错误: ${response.statusCode} - ${response.body}');
          return <String, dynamic>{
            'success': false, 
            'message': '服务器返回错误: ${response.statusCode}', 
            'error': response.body,
            'changes': []
          };
        }
        
        debugPrint('服务器响应内容: ${response.body}');
        
        // 安全解析响应
        try {
          final dynamic rawResult = json.decode(response.body);
          
          if (rawResult is! Map) {
            debugPrint('服务器返回的不是有效的JSON对象: ${response.body}');
            return <String, dynamic>{
              'success': false,
              'message': '服务器返回格式错误',
              'rawResponse': response.body,
              'changes': []
            };
          }
          
          // 将动态Map转换为String, dynamic类型
          final Map<String, dynamic> result = Map<String, dynamic>.from(rawResult as Map);
          
          debugPrint('同步完成，服务器返回: $result');
          return result;
        } catch (e) {
          debugPrint('解析服务器响应时出错: $e');
          return <String, dynamic>{
            'success': false,
            'message': '解析服务器响应时出错: $e',
            'rawResponse': response.body,
            'changes': []
          };
        }
      } catch (e) {
        debugPrint('发送同步请求时出错: $e');
        
        if (e is TimeoutException) {
          return <String, dynamic>{
            'success': false,
            'message': '同步请求超时，请稍后重试',
            'error': e.toString(),
            'changes': []
          };
        } else if (e is SocketException) {
          return <String, dynamic>{
            'success': false,
            'message': '网络连接错误，请检查网络连接',
            'error': e.toString(),
            'changes': []
          };
        } else {
          return <String, dynamic>{
            'success': false,
            'message': '同步请求失败: $e',
            'error': e.toString(),
            'changes': []
          };
        }
      }
    } catch (e, stackTrace) {
      // 捕获和记录顶层异常，确保不会有未处理的异常
      debugPrint('同步日程过程中发生未预期的严重错误: $e');
      debugPrint('错误堆栈: $stackTrace');
      
      return <String, dynamic>{
        'success': false,
        'message': '同步过程中发生严重错误: $e',
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
        'changes': []
      };
    }
  }
} 