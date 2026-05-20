// lib/models/content.dart
// Content（学习内容主表）数据模型

import 'package:uuid/uuid.dart';

/// 学习内容数据模型
/// 存储所有需要学习的字词、诗句、英语、数学题等内容
class Content {
  /// 唯一标识符（UUID v4）
  final String id;

  /// 内容本身（单个字、词语、诗句等）
  final String content;

  /// 类型枚举：chinese_char, chinese_word, chinese_poem, poem_char, english_word, english_phrase, math_question
  final String type;

  /// 父内容ID（错字关联原诗）
  final String? parentId;

  /// 错字在原诗中的字符位置索引
  final int? charIndex;

  /// 古诗词全文（仅chinese_poem类型使用）
  final String? fullText;

  /// 提示信息（拼音/作者朝代等辅助信息）
  final String? hint;

  /// 标准答案（数学问题等使用）
  final String? answer;

  /// 例句/上下文
  final String? context;

  /// 来源（文件名或手动添加标识）
  final String source;

  /// 创建时间
  final DateTime createdAt;

  Content({
    String? id,
    required this.content,
    required this.type,
    this.parentId,
    this.charIndex,
    this.fullText,
    this.hint,
    this.answer,
    this.context,
    required this.source,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// 从数据库Map创建Content对象
  factory Content.fromMap(Map<String, dynamic> map) {
    return Content(
      id: map['id'] as String,
      content: map['content'] as String,
      type: map['type'] as String,
      parentId: map['parent_id'] as String?,
      charIndex: map['char_index'] as int?,
      fullText: map['full_text'] as String?,
      hint: map['hint'] as String?,
      answer: map['answer'] as String?,
      context: map['context'] as String?,
      source: map['source'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'type': type,
      'parent_id': parentId,
      'char_index': charIndex,
      'full_text': fullText,
      'hint': hint,
      'answer': answer,
      'context': context,
      'source': source,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// 创建副本（copyWith）
  Content copyWith({
    String? id,
    String? content,
    String? type,
    String? parentId,
    int? charIndex,
    String? fullText,
    String? hint,
    String? answer,
    String? context,
    String? source,
    DateTime? createdAt,
  }) {
    return Content(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      charIndex: charIndex ?? this.charIndex,
      fullText: fullText ?? this.fullText,
      hint: hint ?? this.hint,
      answer: answer ?? this.answer,
      context: context ?? this.context,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Content{id: $id, content: $content, type: $type, source: $source}';
  }
}
