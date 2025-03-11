import 'package:flutter/material.dart';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'dart:convert'; // 添加JSON支持

class CalendarBook {
  final String id; // 日历本唯一ID
  final String name; // 日历本名称
  final Color color; // 日历本颜色
  final bool isShared; // 是否为共享日历
  final String? ownerId; // 日历所有者ID
  final List<String> sharedWithUsers; // 共享给的用户列表
  final DateTime createdAt; // 添加创建时间
  final DateTime updatedAt; // 添加更新时间

  CalendarBook({
    required this.id,
    required this.name,
    required this.color,
    this.isShared = false,
    this.ownerId,
    this.sharedWithUsers = const [],
    DateTime? createdAt, // 创建时间参数
    DateTime? updatedAt, // 更新时间参数
  }) : this.createdAt = createdAt ?? DateTime.now(),
       this.updatedAt = updatedAt ?? DateTime.now();

  // 从Map创建CalendarBook对象（用于从数据库读取）
  factory CalendarBook.fromMap(Map<String, dynamic> map) {
    List<String> parseSharedUsers() {
      try {
        if (map['sharedWithUsers'] == null) return [];
        if (map['sharedWithUsers'] is String) {
          // 尝试将JSON字符串解析为List<String>
          final decoded = jsonDecode(map['sharedWithUsers']);
          if (decoded is List) {
            return List<String>.from(decoded);
          }
        } else if (map['sharedWithUsers'] is List) {
          return List<String>.from(map['sharedWithUsers']);
        }
      } catch (e) {
        debugPrint('解析sharedWithUsers失败: $e');
      }
      return [];
    }

    // 确保必要的字段不为null，提供默认值
    final String id = map['id'] ?? 'default';
    final String name = map['name'] ?? '默认日历';
    final int colorValue = map['color'] ?? Colors.blue.value;

    return CalendarBook(id: id, name: name, color: Color(colorValue), isShared: map['isShared'] == 1, ownerId: map['ownerId'], sharedWithUsers: parseSharedUsers(), createdAt: map['createdAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['createdAt']) : DateTime.now(), updatedAt: map['updatedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt']) : DateTime.now());
  }

  // 将CalendarBook对象转换为Map（用于存储到数据库）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color.value,
      'isShared': isShared ? 1 : 0,
      'ownerId': ownerId,
      // 将List<String>转换为JSON字符串
      'sharedWithUsers': jsonEncode(sharedWithUsers),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  // 本地数据库事件-创建新日历本
  factory CalendarBook.create({required String name, required Color color, String? ownerId}) {
    debugPrint('本地数据库事件-创建新日历本: $name, $color, $ownerId');
    final DateTime now = DateTime.now();
    return CalendarBook(
      id: const Uuid().v4(),
      name: name,
      color: color,
      ownerId: ownerId,
      isShared: ownerId != null,
      createdAt: now, // 设置创建时间
      updatedAt: now, // 设置更新时间
    );
  }

  // 创建共享日历本
  factory CalendarBook.shared({required String id, required String name, required Color color, required String ownerId}) {
    // 创建一个共享日历本实例
    return CalendarBook(id: id, name: name, color: color, isShared: true, ownerId: ownerId, sharedWithUsers: []);
  }

  // 添加共享用户
  CalendarBook copyWithSharedUser(String userId) {
    final updatedSharedUsers = List<String>.from(sharedWithUsers);
    if (!updatedSharedUsers.contains(userId)) {
      updatedSharedUsers.add(userId);
    }

    return CalendarBook(id: id, name: name, color: color, isShared: isShared, ownerId: ownerId, sharedWithUsers: updatedSharedUsers, createdAt: createdAt, updatedAt: updatedAt);
  }

  // 移除共享用户
  CalendarBook copyWithoutSharedUser(String userId) {
    final updatedSharedUsers = List<String>.from(sharedWithUsers);
    updatedSharedUsers.remove(userId);

    return CalendarBook(id: id, name: name, color: color, isShared: isShared, ownerId: ownerId, sharedWithUsers: updatedSharedUsers, createdAt: createdAt, updatedAt: updatedAt);
  }

  // 更新日历本名称
  CalendarBook copyWithName(String newName) {
    return CalendarBook(id: id, name: newName, color: color, isShared: isShared, ownerId: ownerId, sharedWithUsers: sharedWithUsers, createdAt: createdAt, updatedAt: updatedAt);
  }

  // 更新日历本颜色
  CalendarBook copyWithColor(Color newColor) {
    return CalendarBook(id: id, name: name, color: newColor, isShared: isShared, ownerId: ownerId, sharedWithUsers: sharedWithUsers, createdAt: createdAt, updatedAt: updatedAt);
  }

  // 创建一个具有相同ID和属性的副本，但可以更改部分属性
  CalendarBook copyWith({String? id, String? name, Color? color, String? ownerId, bool? isShared}) {
    return CalendarBook(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      isShared: isShared ?? this.isShared,
      ownerId: ownerId ?? this.ownerId,
      sharedWithUsers: this.sharedWithUsers,
      createdAt: this.createdAt, // 保持创建时间不变
      updatedAt: DateTime.now(), // 更新时间为当前时间
    );
  }

  // 生成分享ID（实际应用中可能需要更复杂的逻辑）
  String generateShareId() {
    final random = Random();
    final randomPart = random.nextInt(10000).toString().padLeft(4, '0');
    return '${id.substring(0, min(4, id.length))}-$randomPart';
  }
}
