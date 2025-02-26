import 'package:flutter/material.dart';
import 'dart:math';

class CalendarBook {
  final String id;           // 日历本唯一ID
  final String name;         // 日历本名称
  final Color color;         // 日历本颜色
  final bool isShared;       // 是否为共享日历
  final String? ownerId;     // 日历所有者ID
  final List<String> sharedWithUsers; // 共享给的用户列表
  final DateTime createdAt;

  CalendarBook({
    required this.id,
    required this.name,
    required this.color,
    this.isShared = false,
    this.ownerId,
    this.sharedWithUsers = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // 从Map创建CalendarBook对象（用于从数据库读取）
  factory CalendarBook.fromMap(Map<String, dynamic> map) {
    return CalendarBook(
      id: map['id'],
      name: map['name'],
      color: Color(map['color']),
      isShared: map['is_shared'] == 1,
      ownerId: map['owner_id'],
      sharedWithUsers: List<String>.from(map['shared_with_users'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }

  // 将CalendarBook对象转换为Map（用于存储到数据库）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color.value,
      'is_shared': isShared ? 1 : 0,
      'owner_id': ownerId,
      'shared_with_users': sharedWithUsers,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  // 创建新日历本
  factory CalendarBook.create({
    required String name,
    required Color color,
    String? ownerId,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    return CalendarBook(
      id: id,
      name: name,
      color: color,
      ownerId: ownerId,
    );
  }

  // 创建共享日历本
  factory CalendarBook.shared({
    required String id,
    required String name,
    required Color color,
    required String ownerId,
  }) {
    return CalendarBook(
      id: id,
      name: name,
      color: color,
      isShared: true,
      ownerId: ownerId,
    );
  }

  // 添加共享用户
  CalendarBook copyWithSharedUser(String userId) {
    final updatedSharedUsers = List<String>.from(sharedWithUsers);
    if (!updatedSharedUsers.contains(userId)) {
      updatedSharedUsers.add(userId);
    }
    
    return CalendarBook(
      id: id,
      name: name,
      color: color,
      isShared: isShared,
      ownerId: ownerId,
      sharedWithUsers: updatedSharedUsers,
      createdAt: createdAt,
    );
  }

  // 移除共享用户
  CalendarBook copyWithoutSharedUser(String userId) {
    final updatedSharedUsers = List<String>.from(sharedWithUsers);
    updatedSharedUsers.remove(userId);
    
    return CalendarBook(
      id: id,
      name: name,
      color: color,
      isShared: isShared,
      ownerId: ownerId,
      sharedWithUsers: updatedSharedUsers,
      createdAt: createdAt,
    );
  }

  // 更新日历本名称
  CalendarBook copyWithName(String newName) {
    return CalendarBook(
      id: id,
      name: newName,
      color: color,
      isShared: isShared,
      ownerId: ownerId,
      sharedWithUsers: sharedWithUsers,
      createdAt: createdAt,
    );
  }

  // 更新日历本颜色
  CalendarBook copyWithColor(Color newColor) {
    return CalendarBook(
      id: id,
      name: name,
      color: newColor,
      isShared: isShared,
      ownerId: ownerId,
      sharedWithUsers: sharedWithUsers,
      createdAt: createdAt,
    );
  }

  // 创建一个具有相同ID和属性的副本，但可以更改部分属性
  CalendarBook copyWith({
    String? name,
    Color? color,
    bool? isShared,
    String? ownerId,
    List<String>? sharedWithUsers,
  }) {
    return CalendarBook(
      id: this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      isShared: isShared ?? this.isShared,
      ownerId: ownerId ?? this.ownerId,
      sharedWithUsers: sharedWithUsers ?? this.sharedWithUsers,
      createdAt: this.createdAt,
    );
  }

  // 生成分享ID（实际应用中可能需要更复杂的逻辑）
  String generateShareId() {
    final random = Random();
    final randomPart = random.nextInt(10000).toString().padLeft(4, '0');
    return '${id.substring(0, min(4, id.length))}-$randomPart';
  }
} 