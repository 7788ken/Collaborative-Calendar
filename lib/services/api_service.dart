import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/calendar_book.dart';
import '../models/schedule_item.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'api_auth_service.dart'; // 添加导入
import '../data/schedule_service.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3002';
  static const Duration defaultTimeout = Duration(seconds: 10); // 默认10秒超时
  static const int maxRetries = 0; // 最大重试次数

  // 检查服务器是否可用
  Future<bool> checkServerStatus() async {
    try {
      debugPrint('ApiService: 开始检查服务器状态');
      final response = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 5));

      debugPrint('ApiService: 服务器响应状态码: ${response.statusCode}');

      // 如果服务器返回200-299之间的状态码，说明服务器正常运行
      return response.statusCode >= 200 && response.statusCode < 300;
    } on TimeoutException {
      debugPrint('ApiService: 服务器状态检查超时');
      return false;
    } on SocketException {
      debugPrint('ApiService: 无法连接到服务器');
      return false;
    } catch (e) {
      debugPrint('ApiService: 检查服务器状态时出错: $e');
      return false;
    }
  }

  // 在执行API请求前检查服务器状态
  Future<void> _checkServerBeforeRequest() async {
    if (!await checkServerStatus()) {
      throw Exception('Connection refused');
    }
  }

  // 用于通用错误处理
  Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      throw Exception('API错误: ${response.statusCode} - ${response.body}');
    }
  }

  // 带有重试机制的HTTP请求函数
  Future<http.Response> _makeRequestWithRetry({required Future<http.Response> Function() requestFunc, int maxRetries = 3, Duration retryDelay = const Duration(seconds: 1)}) async {
    // 先检查服务器状态
    await _checkServerBeforeRequest();

    int attempts = 0;

    while (true) {
      attempts++;
      try {
        debugPrint('ApiService: 尝试发送请求 (尝试 $attempts/$maxRetries)');
        final response = await requestFunc().timeout(defaultTimeout);
        debugPrint('ApiService: 请求成功，状态码: ${response.statusCode}');
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

        // 在重试前检查服务器状态
        if (!await checkServerStatus()) {
          throw Exception('Connection refused');
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
    // 先检查服务器状态
    await _checkServerBeforeRequest();

    try {
      debugPrint('开始共享日历: ${calendar.name}');
      // 确保日期字段被正确转换为毫秒时间戳格式
      final schedulesData =
          schedules.map((s) {
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

      final response = await http.post(Uri.parse('$baseUrl/api/calendars/share'), headers: {'Content-Type': 'application/json'}, body: json.encode({'name': calendar.name, 'color': calendar.color.value.toRadixString(16), 'schedules': schedulesData}));

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
    // 先检查服务器状态
    await _checkServerBeforeRequest();

    try {
      debugPrint('开始获取共享日历信息，分享码: $shareCode');

      try {
        // 生成API认证头
        final String path = '/api/calendars/$shareCode';
        final Map<String, String> headers = ApiAuthService.generateAuthHeaders(path);

        debugPrint('ApiService: 使用认证头: $headers');

        // 打印完整的请求信息用于调试
        final Uri uri = Uri.parse('$baseUrl$path');
        debugPrint('ApiService: 完整请求URL: $uri');
        debugPrint('ApiService: 请求方法: GET');
        debugPrint('ApiService: 请求头: $headers');

        final response = await _makeRequestWithRetry(requestFunc: () => http.get(uri, headers: headers));

        debugPrint('服务器响应状态码: ${response.statusCode}');

        // 检查HTTP状态码
        if (response.statusCode < 200 || response.statusCode >= 300) {
          debugPrint('服务器返回错误状态码: ${response.statusCode}');
          debugPrint('服务器响应内容: ${response.body}');
          throw Exception('服务器返回错误状态码: ${response.statusCode}');
        }

        // 检查响应体是否为空
        if (response.body.isEmpty) {
          debugPrint('服务器返回空响应');
          throw Exception('服务器返回空响应');
        }

        // 记录原始响应内容用于调试
        debugPrint('服务器响应内容: ${response.body}');

        // 尝试解析JSON响应
        Map<String, dynamic> data;
        try {
          data = json.decode(response.body);
        } catch (e) {
          debugPrint('解析JSON出错: $e');
          throw Exception('解析服务器响应失败: $e');
        }

        // 服务器可能返回错误信息
        if (data.containsKey('error')) {
          debugPrint('服务器返回错误信息: ${data['error']}');
          throw Exception('服务器错误: ${data['error']}');
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
            throw Exception('calendar字段格式无效');
          }
        } else if (data.containsKey('name') && data.containsKey('color')) {
          // 直接返回了日历对象
          debugPrint('服务器直接返回了日历数据');
          return data;
        } else {
          // 缺少必要字段
          debugPrint('API返回的数据不符合预期: $data');
          throw Exception('返回数据缺少必要字段');
        }
      } catch (e) {
        debugPrint('获取共享日历过程中出错: $e');
        throw Exception('获取日历信息失败: $e');
      }
    } catch (e) {
      // 最外层的错误处理，确保永远不会抛出未捕获的异常
      debugPrint('获取共享日历过程中发生严重错误: $e');
      throw Exception('获取日历信息失败: $e');
    }
  }

  // 获取日历最后更新时间
  Future<DateTime?> getCalendarLastUpdateTime(String shareCode) async {
    // 先检查服务器状态
    await _checkServerBeforeRequest();

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

      // 优先检查 updatedAt 字段
      if (calendarInfo.containsKey('updatedAt') && calendarInfo['updatedAt'] != null) {
        final updatedAt = calendarInfo['updatedAt'];
        debugPrint('找到 updatedAt 字段: $updatedAt (类型: ${updatedAt.runtimeType})');

        try {
          // 如果是字符串格式的日期时间 (如 "2025-03-06 16:04:04")
          if (updatedAt is String) {
            // 尝试解析日期时间字符串
            final result = DateTime.parse(updatedAt.replaceAll(' ', 'T'));
            debugPrint('成功将 updatedAt 解析为日期时间: $result');
            return result;
          }
          // 如果是整数时间戳
          else if (updatedAt is int) {
            final result = DateTime.fromMillisecondsSinceEpoch(updatedAt);
            debugPrint('成功将 updatedAt 时间戳解析为日期时间: $result');
            return result;
          }
        } catch (e) {
          debugPrint('解析 updatedAt 字段失败: $e，将尝试其他字段');
        }
      }

      // 如果 updatedAt 字段不存在或解析失败，尝试其他可能的字段
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
          // 尝试将空格替换为T，以符合ISO 8601格式
          final formattedTimestamp = timestamp.replaceAll(' ', 'T');
          // 首先尝试作为ISO字符串解析
          final result = DateTime.parse(formattedTimestamp);
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
    // 先检查服务器状态
    await _checkServerBeforeRequest();

    try {
      debugPrint('ApiService: 开始更新共享日历信息，shareCode=$shareCode');

      // 准备要发送的数据
      final Map<String, dynamic> calendarData = {'name': name, 'color': colorValue.toRadixString(16)};

      debugPrint('ApiService: 准备发送的数据: $calendarData');

      // 生成API认证头
      final String path = '/api/calendars/$shareCode';
      final Map<String, String> headers = ApiAuthService.generateAuthHeaders(path);

      // 打印完整的请求信息用于调试
      final Uri uri = Uri.parse('$baseUrl$path');

      final response = await http.put(uri, headers: headers, body: json.encode(calendarData));

      if (response.statusCode >= 400) {
        throw Exception('服务器返回错误: ${response.statusCode} - ${response.body}');
      }

      final responseData = await _handleResponse(response);
      debugPrint('ApiService: 日历更新成功，服务器响应: $responseData');
    } catch (e) {
      debugPrint('ApiService: 更新共享日历信息时出错: $e');
      rethrow;
    }
  }

  // 日程管理API

  // 获取日历下所有日程
  Future<List<dynamic>> getSchedules(String shareCode) async {
    // 先检查服务器状态
    await _checkServerBeforeRequest();

    try {
      debugPrint('开始获取日历日程，分享码: $shareCode');

      final String path = '/api/calendars/$shareCode/schedules';
      final Uri uri = Uri.parse('$baseUrl$path');
      debugPrint('请求URL: $uri');

      // 生成API认证头
      final Map<String, String> headers = ApiAuthService.generateAuthHeaders(path);

      // 添加其他必要的头信息
      headers['Accept'] = 'application/json';
      headers['X-Date-Format'] = 'timestamp'; // 告诉服务器我们期望timestamp格式

      debugPrint('ApiService: 使用认证头: $headers');

      final response = await _makeRequestWithRetry(requestFunc: () => http.get(uri, headers: headers));

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
            List<dynamic> processedSchedules =
                schedules.map((schedule) {
                  // 打印每个日程的详细信息用于调试
                  debugPrint('处理日程: ${schedule['title']} (ID: ${schedule['id']})');
                  debugPrint('原始数据: $schedule');

                  // 确保startTime和endTime是整数时间戳格式
                  var startTime = schedule['startTime'];
                  var endTime = schedule['endTime'];

                  // 处理开始时间
                  if (startTime is! int) {
                    debugPrint('警告: startTime不是整数: $startTime (类型: ${startTime.runtimeType})');
                    if (startTime is String) {
                      try {
                        if (startTime.contains('T') || startTime.contains(' ')) {
                          // 如果是ISO格式或标准日期时间格式
                          startTime = DateTime.parse(startTime).millisecondsSinceEpoch;
                        } else {
                          // 如果是纯数字字符串
                          startTime = int.parse(startTime);
                        }
                        debugPrint('成功转换startTime为时间戳: $startTime');
                      } catch (e) {
                        debugPrint('无法将startTime解析为整数: $e');
                        startTime = DateTime.now().millisecondsSinceEpoch;
                      }
                    } else {
                      startTime = DateTime.now().millisecondsSinceEpoch;
                    }
                  }

                  // 处理结束时间
                  if (endTime is! int) {
                    debugPrint('警告: endTime不是整数: $endTime (类型: ${endTime.runtimeType})');
                    if (endTime is String) {
                      try {
                        if (endTime.contains('T') || endTime.contains(' ')) {
                          // 如果是ISO格式或标准日期时间格式
                          endTime = DateTime.parse(endTime).millisecondsSinceEpoch;
                        } else {
                          // 如果是纯数字字符串
                          endTime = int.parse(endTime);
                        }
                        debugPrint('成功转换endTime为时间戳: $endTime');
                      } catch (e) {
                        debugPrint('无法将endTime解析为整数: $e');
                        // 使用开始时间加一小时作为默认结束时间
                        endTime = startTime + (60 * 60 * 1000);
                      }
                    } else {
                      // 使用开始时间加一小时作为默认结束时间
                      endTime = startTime + (60 * 60 * 1000);
                    }
                  }

                  // 处理其他字段
                  final processedSchedule = {'id': schedule['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(), 'title': schedule['title'] ?? '无标题', 'description': schedule['description'] ?? '', 'location': schedule['location'] ?? '', 'startTime': startTime, 'endTime': endTime, 'isAllDay': schedule['isAllDay'] == 1 || schedule['isAllDay'] == true ? 1 : 0, 'isCompleted': schedule['isCompleted'] == 1 || schedule['isCompleted'] == true ? 1 : 0};

                  debugPrint('处理后的日程数据: $processedSchedule');
                  return processedSchedule;
                }).toList();

            debugPrint('成功处理 ${processedSchedules.length} 个日程');
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

          // 处理列表中的每个日程
          List<dynamic> processedSchedules =
              data.map((schedule) {
                // 打印每个日程的详细信息用于调试
                debugPrint('处理日程: ${schedule['title']} (ID: ${schedule['id']})');
                debugPrint('原始数据: $schedule');

                // 确保startTime和endTime是整数时间戳格式
                var startTime = schedule['startTime'];
                var endTime = schedule['endTime'];

                // 处理开始时间
                if (startTime is! int) {
                  debugPrint('警告: startTime不是整数: $startTime (类型: ${startTime.runtimeType})');
                  if (startTime is String) {
                    try {
                      if (startTime.contains('T') || startTime.contains(' ')) {
                        // 如果是ISO格式或标准日期时间格式
                        startTime = DateTime.parse(startTime).millisecondsSinceEpoch;
                      } else {
                        // 如果是纯数字字符串
                        startTime = int.parse(startTime);
                      }
                      debugPrint('成功转换startTime为时间戳: $startTime');
                    } catch (e) {
                      debugPrint('无法将startTime解析为整数: $e');
                      startTime = DateTime.now().millisecondsSinceEpoch;
                    }
                  } else {
                    startTime = DateTime.now().millisecondsSinceEpoch;
                  }
                }

                // 处理结束时间
                if (endTime is! int) {
                  debugPrint('警告: endTime不是整数: $endTime (类型: ${endTime.runtimeType})');
                  if (endTime is String) {
                    try {
                      if (endTime.contains('T') || endTime.contains(' ')) {
                        // 如果是ISO格式或标准日期时间格式
                        endTime = DateTime.parse(endTime).millisecondsSinceEpoch;
                      } else {
                        // 如果是纯数字字符串
                        endTime = int.parse(endTime);
                      }
                      debugPrint('成功转换endTime为时间戳: $endTime');
                    } catch (e) {
                      debugPrint('无法将endTime解析为整数: $e');
                      // 使用开始时间加一小时作为默认结束时间
                      endTime = startTime + (60 * 60 * 1000);
                    }
                  } else {
                    // 使用开始时间加一小时作为默认结束时间
                    endTime = startTime + (60 * 60 * 1000);
                  }
                }

                // 处理其他字段
                final processedSchedule = {'id': schedule['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(), 'title': schedule['title'] ?? '无标题', 'description': schedule['description'] ?? '', 'location': schedule['location'] ?? '', 'startTime': startTime, 'endTime': endTime, 'isAllDay': schedule['isAllDay'] == 1 || schedule['isAllDay'] == true ? 1 : 0, 'isCompleted': schedule['isCompleted'] == 1 || schedule['isCompleted'] == true ? 1 : 0};

                debugPrint('处理后的日程数据: $processedSchedule');
                return processedSchedule;
              }).toList();

          debugPrint('成功处理 ${processedSchedules.length} 个日程');
          return processedSchedules;
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
    // 先检查服务器状态
    await _checkServerBeforeRequest();

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
        'isCompleted': schedule.isCompleted ? 1 : 0,
      };

      debugPrint('ApiService: 准备发送的数据: $scheduleData');

      // 生成API认证头
      final String path = '/api/calendars/$shareCode/schedules';
      final Map<String, String> headers = ApiAuthService.generateAuthHeaders(path);

      debugPrint('ApiService: 使用认证头: $headers');

      // 打印完整的请求信息用于调试
      final Uri uri = Uri.parse('$baseUrl$path');
      debugPrint('ApiService: 完整请求URL: $uri');
      debugPrint('ApiService: 请求方法: POST');
      debugPrint('ApiService: 请求头: $headers');
      debugPrint('ApiService: 请求体: ${json.encode(scheduleData)}');

      final response = await http.post(uri, headers: headers, body: json.encode(scheduleData));

      debugPrint('ApiService: 服务器响应状态码: ${response.statusCode}');
      debugPrint('ApiService: 服务器响应内容: ${response.body}');

      if (response.statusCode >= 400) {
        debugPrint('ApiService: 服务器返回错误: ${response.statusCode} - ${response.body}');
        throw Exception('服务器返回错误: ${response.statusCode} - ${response.body}');
      }

      final responseData = await _handleResponse(response);
      debugPrint('ApiService: 日程添加成功，服务器响应: $responseData');
      return responseData;
    } catch (e) {
      debugPrint('ApiService: 添加日程时出错: $e');
      rethrow;
    }
  }

  // 更新日程
  Future<Map<String, dynamic>> updateSchedule(String shareCode, String scheduleId, ScheduleItem schedule) async {
    // 先检查服务器状态
    await _checkServerBeforeRequest();

    try {
      debugPrint('ApiService: 开始更新日程，shareCode=$shareCode, scheduleId=$scheduleId');

      // 准备要发送的数据
      final Map<String, dynamic> scheduleData = {'title': schedule.title, 'description': schedule.description ?? '', 'location': schedule.location ?? '', 'startTime': schedule.startTime.millisecondsSinceEpoch, 'endTime': schedule.endTime.millisecondsSinceEpoch, 'isAllDay': schedule.isAllDay ? 1 : 0, 'isCompleted': schedule.isCompleted ? 1 : 0};

      debugPrint('ApiService: 准备发送的更新数据: $scheduleData');

      // 生成API认证头
      final String path = '/api/calendars/$shareCode/schedules/$scheduleId';
      final Map<String, String> headers = ApiAuthService.generateAuthHeaders(path);

      debugPrint('ApiService: 使用认证头: $headers');

      // 打印完整的请求信息用于调试
      final Uri uri = Uri.parse('$baseUrl$path');
      debugPrint('ApiService: 完整请求URL: $uri');
      debugPrint('ApiService: 请求方法: PUT');
      debugPrint('ApiService: 请求头: $headers');
      debugPrint('ApiService: 请求体: ${json.encode(scheduleData)}');

      final response = await http.put(uri, headers: headers, body: json.encode(scheduleData));

      debugPrint('ApiService: 服务器响应状态码: ${response.statusCode}');
      debugPrint('ApiService: 服务器响应内容: ${response.body}');

      if (response.statusCode >= 400) {
        debugPrint('ApiService: 服务器返回错误: ${response.statusCode} - ${response.body}');
        throw Exception('服务器返回错误: ${response.statusCode} - ${response.body}');
      }

      final responseData = await _handleResponse(response);
      debugPrint('ApiService: 日程更新成功，服务器响应: $responseData');
      return responseData;
    } catch (e) {
      debugPrint('ApiService: 更新日程时出错: $e');
      rethrow;
    }
  }

  // 删除日程
  Future<Map<String, dynamic>> deleteSchedule(String shareCode, String scheduleId) async {
    // 先检查服务器状态
    await _checkServerBeforeRequest();

    try {
      debugPrint('ApiService: 开始删除日程，shareCode=$shareCode, scheduleId=$scheduleId');

      // 生成API认证头
      final String path = '/api/calendars/$shareCode/schedules/$scheduleId';
      final Map<String, String> headers = ApiAuthService.generateAuthHeaders(path);

      debugPrint('ApiService: 使用认证头: $headers');

      // 打印完整的请求信息用于调试
      final Uri uri = Uri.parse('$baseUrl$path');
      debugPrint('ApiService: 完整请求URL: $uri');
      debugPrint('ApiService: 请求方法: DELETE');
      debugPrint('ApiService: 请求头: $headers');

      final response = await http.delete(uri, headers: headers);

      debugPrint('ApiService: 服务器响应状态码: ${response.statusCode}');
      debugPrint('ApiService: 服务器响应内容: ${response.body}');

      if (response.statusCode >= 400) {
        debugPrint('ApiService: 服务器返回错误: ${response.statusCode} - ${response.body}');
        throw Exception('服务器返回错误: ${response.statusCode} - ${response.body}');
      }

      final responseData = await _handleResponse(response);
      debugPrint('ApiService: 日程删除成功，服务器响应: $responseData');
      return responseData;
    } catch (e) {
      debugPrint('ApiService: 删除日程时出错: $e');
      rethrow;
    }
  }

  // 批量同步API

  // 批量同步日程（处理离线编辑后的同步）
  Future<Map<String, dynamic>> syncSchedules(String shareCode, List<Map<String, dynamic>> changes) async {
    // 先检查服务器状态
    await _checkServerBeforeRequest();

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

        // 生成API认证头
        final String path = '/api/calendars/$shareCode/sync';
        final Map<String, String> headers = ApiAuthService.generateAuthHeaders(path);

        debugPrint('ApiService: 使用认证头: $headers');

        final response = await http
            .post(Uri.parse('$baseUrl/api/calendars/$shareCode/sync'), headers: headers, body: json.encode({'changes': formattedChanges}))
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () {
                debugPrint('同步请求超时');
                throw TimeoutException('同步请求超时');
              },
            );

        debugPrint('服务器响应状态码: ${response.statusCode}');

        if (response.statusCode >= 400) {
          debugPrint('服务器返回错误: ${response.statusCode} - ${response.body}');
          return <String, dynamic>{'success': false, 'message': '服务器返回错误: ${response.statusCode}', 'error': response.body, 'changes': []};
        }

        debugPrint('服务器响应内容: ${response.body}');

        // 安全解析响应
        try {
          final dynamic rawResult = json.decode(response.body);

          if (rawResult is! Map) {
            debugPrint('服务器返回的不是有效的JSON对象: ${response.body}');
            return <String, dynamic>{'success': false, 'message': '服务器返回格式错误', 'rawResponse': response.body, 'changes': []};
          }

          // 将动态Map转换为String, dynamic类型
          final Map<String, dynamic> result = Map<String, dynamic>.from(rawResult as Map);

          debugPrint('同步完成，服务器返回: $result');
          return result;
        } catch (e) {
          debugPrint('解析服务器响应时出错: $e');
          return <String, dynamic>{'success': false, 'message': '解析服务器响应时出错: $e', 'rawResponse': response.body, 'changes': []};
        }
      } catch (e) {
        debugPrint('发送同步请求时出错: $e');

        if (e is TimeoutException) {
          return <String, dynamic>{'success': false, 'message': '同步请求超时，请稍后重试', 'error': e.toString(), 'changes': []};
        } else if (e is SocketException) {
          return <String, dynamic>{'success': false, 'message': '网络连接错误，请检查网络连接', 'error': e.toString(), 'changes': []};
        } else {
          return <String, dynamic>{'success': false, 'message': '同步请求失败: $e', 'error': e.toString(), 'changes': []};
        }
      }
    } catch (e, stackTrace) {
      // 捕获和记录顶层异常，确保不会有未处理的异常
      debugPrint('同步日程过程中发生未预期的严重错误: $e');
      debugPrint('错误堆栈: $stackTrace');

      return <String, dynamic>{'success': false, 'message': '同步过程中发生严重错误: $e', 'error': e.toString(), 'stackTrace': stackTrace.toString(), 'changes': []};
    }
  }

  // 处理API调用失败并标记未同步状态
  Future<void> handleApiError(ScheduleItem schedule, dynamic error, BuildContext? context) async {
    debugPrint('ApiService: API调用失败，标记为未同步状态');

    try {
      final scheduleService = ScheduleService();
      final updatedSchedule = schedule.copyWith(isSynced: false);
      await scheduleService.updateSchedule(updatedSchedule);
      debugPrint('ApiService: 已将日程标记为未同步状态');

      if (context != null && context.mounted) {
        String errorMessage = '网络同步失败，将在网络恢复后自动同步';
        if (error.toString().contains('Connection refused')) {
          errorMessage = '无法连接到服务器，本地更改将在网络恢复后自动同步';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      debugPrint('ApiService: 更新同步状态时出错: $e');
    }
  }

  // 标记同步成功
  Future<void> markSyncSuccess(ScheduleItem schedule) async {
    debugPrint('ApiService: API调用成功，标记为已同步状态');

    try {
      final scheduleService = ScheduleService();
      final updatedSchedule = schedule.copyWith(isSynced: true);
      await scheduleService.updateSchedule(updatedSchedule);
      debugPrint('ApiService: 已将日程标记为已同步状态');
    } catch (e) {
      debugPrint('ApiService: 更新同步状态时出错: $e');
    }
  }

  // 更新特定日程的状态
  Future<Map<String, dynamic>> updateScheduleStatus(String shareCode, String scheduleId, bool isCompleted, ScheduleItem schedule, BuildContext? context) async {
    try {
      debugPrint('开始更新日程状态: shareCode=$shareCode, scheduleId=$scheduleId, isCompleted=$isCompleted');

      // 生成 API 认证头
      final String path = '/api/calendars/$shareCode/schedules/$scheduleId';
      final Map<String, String> authHeaders = ApiAuthService.generateAuthHeaders(path);

      final response = await _makeRequestWithRetry(requestFunc: () => http.put(Uri.parse('$baseUrl$path'), headers: {'Content-Type': 'application/json', ...authHeaders}, body: json.encode({'isCompleted': isCompleted})));

      final result = await _handleResponse(response);

      if (result['success'] == true) {
        await markSyncSuccess(schedule);
      } else {
        await handleApiError(schedule, Exception(result['message']), context);
      }

      return result;
    } catch (e) {
      await handleApiError(schedule, e, context);
      rethrow;
    }
  }
}
