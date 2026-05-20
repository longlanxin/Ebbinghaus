// lib/models/poem_error.dart
// PoemError（古诗词错字明细）数据模型

import 'package:uuid/uuid.dart';

/// 古诗词错字记录模型
/// 记录孩子在默写古诗词时写错的字及其相关信息
class PoemError {
  /// 唯一标识符
  final String id;

  /// 关联的古诗词ID
  final String poemId;

  /// 错字在全诗中的字符位置索引
  final int charIndex;

  /// 正确的标准字
  final String standardChar;

  /// 孩子实际写错的字（可能为空表示不记得写了什么）
  String? wrongChar;

  /// 错误发生日期
  final DateTime errorDate;

  /// 复习次数（记录被复习了多少次）
  int reviewCount;

  PoemError({
    String? id,
    required this.poemId,
    required this.charIndex,
    required this.standardChar,
    this.wrongChar,
    this.reviewCount = 0,
    DateTime? errorDate,
  })  : id = id ?? const Uuid().v4(),
        errorDate = errorDate ?? DateTime.now();

  /// 从数据库Map创建PoemError对象
  factory PoemError.fromMap(Map<String, dynamic> map) {
    return PoemError(
      id: map['id'] as String,
      poemId: map['poem_id'] as String,
      charIndex: map['char_index'] as int,
      standardChar: map['standard_char'] as String,
      wrongChar: map['wrong_char'] as String?,
      reviewCount: map['review_count'] as int? ?? 0,
      errorDate: DateTime.fromMillisecondsSinceEpoch(map['error_date'] as int),
    );
  }

  /// 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'poem_id': poemId,
      'char_index': charIndex,
      'standard_char': standardChar,
      'wrong_char': wrongChar,
      'error_date': errorDate.millisecondsSinceEpoch,
      'review_count': reviewCount,
    };
  }

  /// 创建副本
  PoemError copyWith({
    String? id,
    String? poemId,
    int? charIndex,
    String? standardChar,
    String? wrongChar,
    int? reviewCount,
    DateTime? errorDate,
  }) {
    return PoemError(
      id: id ?? this.id,
      poemId: poemId ?? this.poemId,
      charIndex: charIndex ?? this.charIndex,
      standardChar: standardChar ?? this.standardChar,
      wrongChar: wrongChar ?? this.wrongChar,
      reviewCount: reviewCount ?? this.reviewCount,
      errorDate: errorDate ?? this.errorDate,
    );
  }

  @override
  String toString() {
    return 'PoemError{poemId: $poemId, charIndex: $charIndex, '
        'standardChar: $standardChar, wrongChar: $wrongChar, '
        'reviewCount: $reviewCount}';
  }
}
