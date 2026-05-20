// lib/models/check_in.dart
// CheckIn（打卡记录）数据模型

import 'package:uuid/uuid.dart';

/// 每日打卡记录模型
/// 记录每天的学习情况：任务数、正确数、错误数、学习时长
class CheckIn {
  /// 唯一标识符
  final String id;

  /// 打卡日期（精确到天）
  final DateTime date;

  /// 当日任务数量
  int taskCount;

  /// 当日正确数量
  int correctCount;

  /// 当日错误数量
  int wrongCount;

  /// 当日学习时长（分钟）
  int? durationMinutes;

  CheckIn({
    String? id,
    required this.date,
    this.taskCount = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.durationMinutes,
  }) : id = id ?? const Uuid().v4();

  /// 从数据库Map创建CheckIn对象
  factory CheckIn.fromMap(Map<String, dynamic> map) {
    return CheckIn(
      id: map['id'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      taskCount: map['task_count'] as int? ?? 0,
      correctCount: map['correct_count'] as int? ?? 0,
      wrongCount: map['wrong_count'] as int? ?? 0,
      durationMinutes: map['duration_minutes'] as int?,
    );
  }

  /// 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': DateTime(date.year, date.month, date.day).millisecondsSinceEpoch,
      'task_count': taskCount,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'duration_minutes': durationMinutes,
    };
  }

  /// 计算正确率（百分比）
  double get accuracyRate {
    if (taskCount == 0) return 0.0;
    return (correctCount / taskCount) * 100;
  }

  /// 是否全部正确
  bool get isAllCorrect => wrongCount == 0 && taskCount > 0;

  /// 创建副本
  CheckIn copyWith({
    String? id,
    DateTime? date,
    int? taskCount,
    int? correctCount,
    int? wrongCount,
    int? durationMinutes,
  }) {
    return CheckIn(
      id: id ?? this.id,
      date: date ?? this.date,
      taskCount: taskCount ?? this.taskCount,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  @override
  String toString() {
    return 'CheckIn{date: $date, taskCount: $taskCount, '
        'correctCount: $correctCount, wrongCount: $wrongCount}';
  }
}
