import 'package:flutter/material.dart';

class ScheduleItem {
  final String title;
  final String startTime;
  final String endTime;
  final String location;
  final String remark;
  final DateTime date;
  bool isCompleted;

  ScheduleItem({
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.remark,
    required this.date,
    this.isCompleted = false,
  });
} 