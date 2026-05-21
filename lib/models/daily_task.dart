// lib/models/daily_task.dart
// DailyTask（每日任务）数据模型

import 'content.dart';
import 'schedule.dart';

// ============================================================
// CheckResult（核对结果）
// ============================================================

/// 单项核对结果
/// 记录听写核对时每个内容的正确/错误情况
class CheckResult {
  /// 内容ID
  final String contentId;

  /// 是否正确
  final bool isCorrect;

  /// 写错的字（如果isCorrect为false时记录）
  final String? wrongChar;

  /// 核对时间
  final DateTime checkedAt;

  CheckResult({
    required this.contentId,
    required this.isCorrect,
    this.wrongChar,
    DateTime? checkedAt,
  }) : checkedAt = checkedAt ?? DateTime.now();

  /// 快速创建正确结果
  factory CheckResult.correct(String contentId) {
    return CheckResult(contentId: contentId, isCorrect: true);
  }

  /// 快速创建错误结果
  factory CheckResult.wrong(String contentId, {String? wrongChar}) {
    return CheckResult(
      contentId: contentId,
      isCorrect: false,
      wrongChar: wrongChar,
    );
  }

  /// 从Map创建
  factory CheckResult.fromMap(Map<String, dynamic> map) {
    return CheckResult(
      contentId: map['content_id'] as String,
      isCorrect: map['is_correct'] as bool,
      wrongChar: map['wrong_char'] as String?,
      checkedAt: DateTime.fromMillisecondsSinceEpoch(map['checked_at'] as int),
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'content_id': contentId,
      'is_correct': isCorrect,
      'wrong_char': wrongChar,
      'checked_at': checkedAt.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() {
    return 'CheckResult{contentId: $contentId, isCorrect: $isCorrect, '
        'wrongChar: $wrongChar}';
  }
}

// ============================================================
// TaskItem（任务项）
// ============================================================

/// 每日任务中的单个任务项
/// 将Content和Schedule组合，并附加任务属性
class TaskItem {
  /// 学习内容
  final Content content;

  /// 学习调度信息
  final Schedule schedule;

  /// 是否为新学内容
  final bool isNew;

  /// 是否为困难词
  final bool isDifficult;

  TaskItem({
    required this.content,
    required this.schedule,
    this.isNew = false,
    this.isDifficult = false,
  });

  /// 获取内容类型
  String get type => content.type;

  /// 获取内容文本
  String get displayText => content.content;

  /// 是否为古诗词
  bool get isPoem => content.type == 'chinese_poem';

  /// 是否为数学问题
  bool get isMath => content.type == 'math_question';

  /// 是否为错字
  bool get isPoemChar => content.type == 'poem_char';

  @override
  String toString() {
    return 'TaskItem{content: ${content.content}, type: ${content.type}, '
        'isNew: $isNew, isDifficult: $isDifficult}';
  }
}

// ============================================================
// DailyTask（每日任务）
// ============================================================

/// 每日任务集合
/// 包含当天所有需要学习/复习的任务项
class DailyTask {
  /// 任务项列表
  final List<TaskItem> items;

  /// 任务日期
  final DateTime date;

  /// 是否包含数学抽查
  final bool hasMathQuiz;

  /// 总任务数量
  int get totalCount => items.length;

  /// 语文任务数量
  int get chineseCount => items.where((item) {
        return item.type == 'chinese_char' ||
            item.type == 'chinese_word' ||
            item.type == 'chinese_poem' ||
            item.type == 'poem_char';
      }).length;

  /// 英语任务数量
  int get englishCount => items.where((item) {
        return item.type == 'english_word' || item.type == 'english_phrase';
      }).length;

  /// 古诗词任务数量
  int get poemCount => items.where((item) => item.type == 'chinese_poem').length;

  /// 数学任务数量
  int get mathCount => items.where((item) => item.type == 'math_question').length;

  /// 新词数量
  int get newWordCount => items.where((item) => item.isNew).length;

  /// 困难词数量
  int get difficultCount => items.where((item) => item.isDifficult).length;

  DailyTask({
    required this.items,
    required this.date,
    this.hasMathQuiz = false,
  });

  /// 空任务（无任务时使用）
  factory DailyTask.empty() {
    return DailyTask(
      items: [],
      date: DateTime.now(),
      hasMathQuiz: false,
    );
  }

  /// 是否为空任务
  bool get isEmpty => items.isEmpty;

  /// 是否有任务
  bool get hasTasks => items.isNotEmpty;

  @override
  String toString() {
    return 'DailyTask{date: $date, totalCount: $totalCount, '
        'chinese: $chineseCount, english: $englishCount, '
        'poem: $poemCount, math: $mathCount, '
        'newWords: $newWordCount, difficult: $difficultCount, '
        'hasMathQuiz: $hasMathQuiz}';
  }
}

// ============================================================
// ImportResult（导入结果）
// ============================================================

/// CSV导入结果
class ImportResult {
  /// 成功导入数量
  final int successCount;

  /// 跳过（重复）数量
  final int skipCount;

  /// 失败数量
  final int failCount;

  /// 错误详情列表
  final List<String> errors;

  /// 成功导入的内容列表
  final List<Content> importedContents;

  ImportResult({
    this.successCount = 0,
    this.skipCount = 0,
    this.failCount = 0,
    this.errors = const [],
    this.importedContents = const [],
  });

  /// 总处理数量
  int get totalCount => successCount + skipCount + failCount;

  /// 是否全部成功
  bool get allSuccess => failCount == 0 && skipCount == 0 && successCount > 0;

  /// 添加一个成功导入
  ImportResult addSuccess(Content content) {
    return ImportResult(
      successCount: successCount + 1,
      skipCount: skipCount,
      failCount: failCount,
      errors: errors,
      importedContents: [...importedContents, content],
    );
  }

  /// 添加一个跳过的
  ImportResult addSkip() {
    return ImportResult(
      successCount: successCount,
      skipCount: skipCount + 1,
      failCount: failCount,
      errors: errors,
      importedContents: importedContents,
    );
  }

  /// 添加一个失败的
  ImportResult addFail(String error) {
    return ImportResult(
      successCount: successCount,
      skipCount: skipCount,
      failCount: failCount + 1,
      errors: [...errors, error],
      importedContents: importedContents,
    );
  }

  @override
  String toString() {
    return 'ImportResult{success: $successCount, skip: $skipCount, '
        'fail: $failCount, errors: ${errors.length}}';
  }
}
