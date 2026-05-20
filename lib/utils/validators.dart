// lib/utils/validators.dart
// 验证工具类
// 提供家长模式验证、CSV数据验证、内容去重等功能

import 'constants.dart';

// ============================================================
// 验证结果类
// ============================================================

/// 验证结果，包含是否通过及错误信息
class ValidationResult {
  /// 验证是否通过
  final bool isValid;

  /// 错误信息列表（验证失败时填充）
  final List<String> errors;

  const ValidationResult._(this.isValid, this.errors);

  /// 验证通过的工厂方法
  factory ValidationResult.valid() {
    return const ValidationResult._(true, []);
  }

  /// 验证失败的工厂方法
  factory ValidationResult.invalid(List<String> errors) {
    return ValidationResult._(false, errors);
  }
}

// ============================================================
// 家长模式验证
// ============================================================

/// 验证家长模式进入答案
///
/// [answer] - 用户输入的答案字符串
/// [expectedAnswer] - 正确答案（由调用方传入，通常是简单算术题的结果）
/// 返回验证结果
///
/// 验证规则：
/// - 答案不能为空
/// - 答案必须是数字
/// - 答案必须等于预期结果
ValidationResult validateParentAnswer(String? answer, int expectedAnswer) {
  final errors = <String>[];

  // 检查是否为空
  if (answer == null || answer.trim().isEmpty) {
    errors.add('答案不能为空');
    return ValidationResult.invalid(errors);
  }

  // 尝试解析为整数
  final parsedValue = int.tryParse(answer.trim());
  if (parsedValue == null) {
    errors.add('答案必须是数字');
    return ValidationResult.invalid(errors);
  }

  // 检查是否等于预期答案
  if (parsedValue != expectedAnswer) {
    errors.add('答案不正确，请重新计算');
    return ValidationResult.invalid(errors);
  }

  return ValidationResult.valid();
}

/// 生成家长模式验证题目
///
/// 生成一道简单的加法算术题（两个不超过20的正整数相加）
/// 返回包含题目和答案的元组 (question, answer)
///
/// 例如：("3 + 5 = ?", 8)
({String question, int answer}) generateParentVerificationQuestion() {
  // 使用当前时间的毫秒数作为随机种子，确保每次不同
  final now = DateTime.now().millisecondsSinceEpoch;
  final random = _SimpleRandom(now);

  final num1 = random.nextInt(kParentModeMaxNum) + 1; // 1 ~ 20
  final num2 = random.nextInt(kParentModeMaxNum) + 1; // 1 ~ 20

  final question = '$num1 + $num2 = ?';
  final answer = num1 + num2;

  return (question: question, answer: answer);
}

// ============================================================
// CSV数据验证
// ============================================================

/// CSV列索引定义
class CsvColumnIndex {
  static const int content = 0;      // 内容
  static const int type = 1;         // 类型
  static const int hint = 2;         // 提示
  static const int answer = 3;       // 答案
  static const int context = 4;      // 上下文/例句
  static const int fullText = 5;     // 古诗词全文
  static const int minColumnCount = 1; // 最少需要1列（内容）
}

/// 验证CSV单行数据
///
/// [row] - CSV解析后的一行数据（字符串列表）
/// [lineNumber] - 行号（用于错误定位）
/// 返回验证结果
///
/// 验证规则：
/// - 行不能为空
/// - 至少包含内容列（第1列）
/// - 内容不能为空字符串
/// - 类型列必须是有效类型（如果有）
/// - 古诗词类型必须包含全文（如果有类型列）
ValidationResult validateCsvRow(List<dynamic> row, int lineNumber) {
  final errors = <String>[];

  // 检查行是否为空
  if (row.isEmpty) {
    errors.add('第$lineNumber行: 空行');
    return ValidationResult.invalid(errors);
  }

  // 检查内容列是否为空
  final content = row[CsvColumnIndex.content]?.toString().trim() ?? '';
  if (content.isEmpty) {
    errors.add('第$lineNumber行: 内容不能为空');
    return ValidationResult.invalid(errors);
  }

  // 如果有类型列，验证类型是否有效
  if (row.length > CsvColumnIndex.type) {
    final typeStr = row[CsvColumnIndex.type]?.toString().trim() ?? '';
    if (typeStr.isNotEmpty) {
      if (!kAllContentTypes.contains(typeStr)) {
        errors.add(
          '第$lineNumber行: 无效的类型 "$typeStr"，有效类型: ${kAllContentTypes.join(", ")}',
        );
      }

      // 古诗词类型需要包含全文
      if (typeStr == typeChinesePoem && row.length > CsvColumnIndex.fullText) {
        final fullText = row[CsvColumnIndex.fullText]?.toString().trim() ?? '';
        if (fullText.isEmpty) {
          errors.add('第$lineNumber行: 古诗词类型必须包含全文');
        }
      }
    }
  }

  if (errors.isNotEmpty) {
    return ValidationResult.invalid(errors);
  }

  return ValidationResult.valid();
}

/// 验证CSV内容值是否有效
///
/// [content] - 内容字符串
/// [source] - 来源标识
/// 返回验证结果
ValidationResult validateCsvContent(String content, String source) {
  final errors = <String>[];

  if (content.trim().isEmpty) {
    errors.add('内容不能为空');
  }

  if (source.trim().isEmpty) {
    errors.add('来源不能为空');
  }

  // 检查内容长度是否合理（防止异常长数据）
  if (content.length > 1000) {
    errors.add('内容过长（最大1000字符）');
  }

  if (errors.isNotEmpty) {
    return ValidationResult.invalid(errors);
  }

  return ValidationResult.valid();
}

// ============================================================
// 内容去重验证
// ============================================================

/// 检查新内容是否与已有内容重复
///
/// [existing] - 已有内容列表（从数据库查询到的内容字符串列表）
/// [newContent] - 新内容字符串
/// 返回 true 表示内容已存在（重复），false 表示不重复
///
/// 去重规则：
/// - 去除首尾空格后比较
/// - 不区分大小写比较（适用于英文内容）
bool isContentDuplicate(List<String> existing, String newContent) {
  final trimmedNew = newContent.trim();
  if (trimmedNew.isEmpty) return false;

  for (final exist in existing) {
    if (exist.trim().toLowerCase() == trimmedNew.toLowerCase()) {
      return true; // 发现重复
    }
  }

  return false; // 未重复
}

/// 检查新内容与已有内容的重复（带来源判断）
///
/// [existingContents] - 已有内容对象的列表，每项为 (content, source) 元组
/// [newContent] - 新内容字符串
/// [newSource] - 新内容来源
/// 返回 true 表示内容和来源都匹配（重复）
bool isContentAndSourceDuplicate(
  List<({String content, String source})> existingContents,
  String newContent,
  String newSource,
) {
  final trimmedNewContent = newContent.trim().toLowerCase();
  final trimmedNewSource = newSource.trim().toLowerCase();

  if (trimmedNewContent.isEmpty) return false;

  for (final exist in existingContents) {
    final contentMatch = exist.content.trim().toLowerCase() == trimmedNewContent;
    final sourceMatch = exist.source.trim().toLowerCase() == trimmedNewSource;
    if (contentMatch && sourceMatch) {
      return true; // 内容和来源都匹配，视为重复
    }
  }

  return false;
}

// ============================================================
// 数学录音评分验证
// ============================================================

/// 验证数学录音评分是否有效
///
/// [rating] - 评分字符串
/// 返回 true 表示评分有效
bool isValidMathRating(String? rating) {
  if (rating == null || rating.isEmpty) return false;
  return [kRatingUnderstood, kRatingFuzzy, kRatingConfused].contains(rating);
}

// ============================================================
// 简单随机数生成器（用于家长模式验证题目）
// 不依赖dart:math，避免额外导入
// ============================================================

class _SimpleRandom {
  int _seed;

  _SimpleRandom(this._seed);

  /// 生成下一个随机整数（0 ~ max-1）
  int nextInt(int max) {
    _seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return _seed % max;
  }
}
