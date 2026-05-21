// lib/models/schedule.dart
// Schedule（艾宾浩斯调度表）数据模型

import 'package:uuid/uuid.dart';

/// 艾宾浩斯学习调度模型
/// 记录每个学习内容的复习计划、错误次数、连续正确次数等状态
class Schedule {
  /// 唯一标识符
  final String id;

  /// 关联的内容ID
  final String contentId;

  /// 下次复习日期（精确到天，时间为00:00:00）
  DateTime nextReviewDate;

  /// 当前间隔天数（对应艾宾浩斯序列中的某个值）
  int intervalDays;

  /// 累计错误次数
  int errorCount;

  /// 连续正确次数
  int consecutiveCorrect;

  /// 状态：new_word, learning, mastered, difficult
  String status;

  /// 最后一次核对结果：correct / wrong
  String? lastResult;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  DateTime updatedAt;

  Schedule({
    String? id,
    required this.contentId,
    required this.nextReviewDate,
    this.intervalDays = 0,
    this.errorCount = 0,
    this.consecutiveCorrect = 0,
    this.status = 'new_word',
    this.lastResult,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 从数据库Map创建Schedule对象
  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: map['id'] as String,
      contentId: map['content_id'] as String,
      nextReviewDate: DateTime.fromMillisecondsSinceEpoch(
        map['next_review_date'] as int,
      ),
      intervalDays: map['interval_days'] as int? ?? 0,
      errorCount: map['error_count'] as int? ?? 0,
      consecutiveCorrect: map['consecutive_correct'] as int? ?? 0,
      status: map['status'] as String? ?? 'new_word',
      lastResult: map['last_result'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  /// 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content_id': contentId,
      'next_review_date': nextReviewDate.millisecondsSinceEpoch,
      'interval_days': intervalDays,
      'error_count': errorCount,
      'consecutive_correct': consecutiveCorrect,
      'status': status,
      'last_result': lastResult,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// 创建副本（copyWith）
  Schedule copyWith({
    String? id,
    String? contentId,
    DateTime? nextReviewDate,
    int? intervalDays,
    int? errorCount,
    int? consecutiveCorrect,
    String? status,
    String? lastResult,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Schedule(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      intervalDays: intervalDays ?? this.intervalDays,
      errorCount: errorCount ?? this.errorCount,
      consecutiveCorrect: consecutiveCorrect ?? this.consecutiveCorrect,
      status: status ?? this.status,
      lastResult: lastResult ?? this.lastResult,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 获取当前间隔在艾宾浩斯序列中的索引
  /// 用于判断下一个间隔应该是什么
  int get currentIntervalIndex {
    // 根据intervalDays找到对应的索引
    if (intervalDays <= 0) return -1;
    if (intervalDays >= 30) return 6;
    if (intervalDays >= 15) return 5;
    if (intervalDays >= 7) return 4;
    if (intervalDays >= 4) return 3;
    if (intervalDays >= 2) return 2;
    return 0; // intervalDays == 1
  }

  @override
  String toString() {
    return 'Schedule{id: $id, contentId: $contentId, status: $status, '
        'intervalDays: $intervalDays, consecutiveCorrect: $consecutiveCorrect, '
        'errorCount: $errorCount}';
  }
}
