import 'package:flutter/material.dart';

class ScheduleItem {
  final DateTime date;
  final String time;
  final String title;
  final String location;
  final String remark;
  bool isCompleted;

  ScheduleItem({
    required this.date,
    required this.time,
    required this.title,
    required this.location,
    this.remark = '',
    this.isCompleted = false,
  });
} 