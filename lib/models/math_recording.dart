// lib/models/math_recording.dart
// MathRecording（数学问答录音）数据模型

import 'package:uuid/uuid.dart';

/// 数学问答录音记录模型
/// 记录孩子回答数学问题的录音文件及家长评分
class MathRecording {
  /// 唯一标识符
  final String id;

  /// 关联的数学问题内容ID
  final String contentId;

  /// 录音文件路径
  final String filePath;

  /// 录音时间
  final DateTime recordedAt;

  /// 家长评分：understood / fuzzy / confused
  String? parentRating;

  /// 评分时间
  DateTime? ratedAt;

  MathRecording({
    String? id,
    required this.contentId,
    required this.filePath,
    required this.recordedAt,
    this.parentRating,
    this.ratedAt,
  }) : id = id ?? const Uuid().v4();

  /// 从数据库Map创建MathRecording对象
  factory MathRecording.fromMap(Map<String, dynamic> map) {
    return MathRecording(
      id: map['id'] as String,
      contentId: map['content_id'] as String,
      filePath: map['file_path'] as String,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(map['recorded_at'] as int),
      parentRating: map['parent_rating'] as String?,
      ratedAt: map['rated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['rated_at'] as int)
          : null,
    );
  }

  /// 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content_id': contentId,
      'file_path': filePath,
      'recorded_at': recordedAt.millisecondsSinceEpoch,
      'parent_rating': parentRating,
      'rated_at': ratedAt?.millisecondsSinceEpoch,
    };
  }

  /// 是否已评分
  bool get isRated => parentRating != null && parentRating!.isNotEmpty;

  /// 创建副本
  MathRecording copyWith({
    String? id,
    String? contentId,
    String? filePath,
    DateTime? recordedAt,
    String? parentRating,
    DateTime? ratedAt,
  }) {
    return MathRecording(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      filePath: filePath ?? this.filePath,
      recordedAt: recordedAt ?? this.recordedAt,
      parentRating: parentRating ?? this.parentRating,
      ratedAt: ratedAt ?? this.ratedAt,
    );
  }

  @override
  String toString() {
    return 'MathRecording{contentId: $contentId, parentRating: $parentRating, '
        'recordedAt: $recordedAt}';
  }
}
