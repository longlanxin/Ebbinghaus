// lib/providers/schedule_manager.dart
// 艾宾浩斯调度管理器
// 核心算法：管理学习内容的复习调度、状态转换、间隔计算
// 包括正确/错误处理、古诗词错字提取、错字复习等

import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/content.dart';
import '../models/schedule.dart';
import '../models/poem_error.dart';
import '../utils/constants.dart';
import '../utils/ebbinghaus.dart';

// ============================================================
// ScheduleManager - 艾宾浩斯调度管理核心类
// ============================================================

/// 调度管理器
/// 负责创建学习调度、处理核对结果、更新间隔和状态
/// 所有数据库操作通过 DatabaseHelper.instance 进行
class ScheduleManager {
  // 单例模式
  static final ScheduleManager _instance = ScheduleManager._internal();
  factory ScheduleManager() => _instance;
  ScheduleManager._internal();

  // ============================================================
  // 1. 创建初始调度
  // ============================================================

  /// 为新导入的内容创建初始schedule
  ///
  /// [contentId] - 内容ID
  /// 新内容的schedule初始状态：
  /// - nextReviewDate = 今天（当天就要学习）
  /// - intervalDays = 0（新词，尚未开始间隔）
  /// - errorCount = 0
  /// - consecutiveCorrect = 0
  /// - status = 'new_word'
  Future<void> createScheduleForContent(String contentId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final schedule = Schedule(
      contentId: contentId,
      nextReviewDate: today,
      intervalDays: 0,
      errorCount: 0,
      consecutiveCorrect: 0,
      status: statusNewWord,
      lastResult: null,
      createdAt: now,
      updatedAt: now,
    );

    // 保存到数据库
    try {
      await DatabaseHelper.instance.insertSchedule(schedule);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】创建初始schedule失败: $e');
      }
      rethrow;
    }

    if (kDebugMode) {
      debugPrint('【ScheduleManager】创建初始schedule: ${schedule.toString()}');
    }
  }

  /// 批量创建多个内容的初始schedule
  ///
  /// [contentIds] - 内容ID列表
  Future<void> createSchedulesForContents(List<String> contentIds) async {
    for (final contentId in contentIds) {
      await createScheduleForContent(contentId);
    }
    if (kDebugMode) {
      debugPrint('【ScheduleManager】批量创建 ${contentIds.length} 个schedule');
    }
  }

  // ============================================================
  // 2. 标记正确 - 艾宾浩斯间隔推进
  // ============================================================

  /// 标记内容回答正确，更新schedule状态
  ///
  /// 处理流程：
  /// 1. consecutiveCorrect + 1
  /// 2. intervalDays 按艾宾浩斯序列推进
  /// 3. consecutiveCorrect >= 5 -> status = 'mastered'
  /// 4. nextReviewDate = 今天 + newIntervalDays
  /// 5. lastResult = 'correct'
  /// 6. status 从 'new_word' 转为 'learning'（首次正确后）
  ///
  /// [contentId] - 内容ID
  /// [schedule] - 当前的schedule对象（若已从数据库获取）
  Future<void> markAsCorrect(String contentId, {Schedule? schedule}) async {
    // 若schedule未传入，从数据库查询
    schedule ??= await DatabaseHelper.instance.getScheduleByContentId(contentId);
    if (schedule == null) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】markAsCorrect: 未找到contentId=$contentId 的schedule');
      }
      return;
    }

    // 1. 连续正确次数 +1
    schedule.consecutiveCorrect += 1;

    // 2. 按艾宾浩斯序列推进间隔
    // 根据当前间隔天数找到下一个间隔值
    final newIntervalDays = advanceInterval(schedule.intervalDays);
    schedule.intervalDays = newIntervalDays;

    // 3. 状态转换
    if (schedule.consecutiveCorrect >= kMasterThreshold) {
      // 连续正确达到掌握阈值，标记为已掌握
      schedule.status = statusMastered;
      if (kDebugMode) {
        debugPrint('【ScheduleManager】contentId=$contentId 连续正确${schedule.consecutiveCorrect}次，标记为已掌握');
      }
    } else if (schedule.status == statusNewWord) {
      // 从new_word首次正确后转为learning
      schedule.status = statusLearning;
    }
    // 如果status已经是difficult，正确后保持difficult（需要连续正确5次才转为mastered）

    // 4. 计算下次复习日期 = 今天 + 新间隔天数
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    schedule.nextReviewDate = calculateNextReviewDate(today, newIntervalDays);

    // 5. 记录最后一次结果为正确
    schedule.lastResult = 'correct';

    // 6. 更新更新时间
    schedule.updatedAt = now;

    // 保存到数据库
    try {
      await DatabaseHelper.instance.updateSchedule(schedule);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】markAsCorrect保存失败: $e');
      }
      rethrow;
    }

    if (kDebugMode) {
      debugPrint('【ScheduleManager】markAsCorrect: contentId=$contentId, '
          'consecutiveCorrect=${schedule.consecutiveCorrect}, '
          'intervalDays=${schedule.intervalDays}, '
          'status=${schedule.status}, '
          'nextReviewDate=${schedule.nextReviewDate}');
    }
  }

  // ============================================================
  // 3. 标记错误 - 间隔缩短 + 困难标记
  // ============================================================

  /// 标记内容回答错误，更新schedule状态
  ///
  /// 处理流程：
  /// 1. errorCount + 1
  /// 2. consecutiveCorrect = 0（连续正确中断）
  /// 3. intervalDays = max(intervalDays ~/ 2, 1)（缩短50%，至少1天）
  /// 4. errorCount >= 2 -> status = 'difficult'
  /// 5. nextReviewDate = 明天（错误后第二天立即复习）
  /// 6. lastResult = 'wrong'
  ///
  /// [contentId] - 内容ID
  /// [schedule] - 当前的schedule对象（若已从数据库获取）
  Future<void> markAsWrong(String contentId, {Schedule? schedule}) async {
    // 若schedule未传入，从数据库查询
    schedule ??= await DatabaseHelper.instance.getScheduleByContentId(contentId);
    if (schedule == null) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】markAsWrong: 未找到contentId=$contentId 的schedule');
      }
      return;
    }

    // 1. 错误次数 +1
    schedule.errorCount += 1;

    // 2. 连续正确次数重置为0
    schedule.consecutiveCorrect = 0;

    // 3. 间隔缩短50%（至少1天）
    schedule.intervalDays = adjustIntervalOnWrong(schedule.intervalDays);

    // 4. 错误次数达到困难阈值，标记为困难
    if (schedule.errorCount >= kDifficultThreshold) {
      schedule.status = statusDifficult;
      if (kDebugMode) {
        debugPrint('【ScheduleManager】contentId=$contentId 错误${schedule.errorCount}次，标记为困难');
      }
    }

    // 5. 下次复习日期 = 明天（错误后需要尽快复习）
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    schedule.nextReviewDate = tomorrow;

    // 6. 记录最后一次结果为错误
    schedule.lastResult = 'wrong';

    // 7. 更新更新时间
    schedule.updatedAt = now;

    // 保存到数据库
    try {
      await DatabaseHelper.instance.updateSchedule(schedule);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】markAsWrong保存失败: $e');
      }
      rethrow;
    }

    if (kDebugMode) {
      debugPrint('【ScheduleManager】markAsWrong: contentId=$contentId, '
          'errorCount=${schedule.errorCount}, '
          'intervalDays=${schedule.intervalDays}, '
          'status=${schedule.status}, '
          'nextReviewDate=${schedule.nextReviewDate}');
    }
  }

  // ============================================================
  // 4. 古诗词错字处理 - 核心特色功能
  // ============================================================

  /// 处理古诗词默写中的错字
  ///
  /// 处理流程：
  /// 1. 将整首诗的schedule按错误更新（调用markAsWrong）
  /// 2. 检查是否已有该错字的记录
  /// 3. 将错字提取为 poem_char 类型的新Content
  /// 4. 为该 poem_char 创建新的schedule
  /// 5. 记录到 poem_errors 表
  ///
  /// [poemId] - 古诗词内容ID
  /// [charIndex] - 错字在全诗中的位置索引
  /// [standardChar] - 正确的标准字
  /// [wrongChar] - 孩子实际写错的字（可为null表示不记得）
  /// [fullText] - 古诗词全文（用于创建错字Content的上下文）
  Future<void> handlePoemCharError(
    String poemId,
    int charIndex,
    String standardChar,
    String? wrongChar, {
    String? fullText,
  }) async {
    if (kDebugMode) {
      debugPrint('【ScheduleManager】古诗词错字处理: poemId=$poemId, '
          'charIndex=$charIndex, standardChar=$standardChar, wrongChar=$wrongChar');
    }

    // 步骤1: 整首诗的schedule按错误更新
    await _updatePoemScheduleOnError(poemId);

    // 步骤2: 检查是否已有该错字的 poem_char Content
    // 通过 parentId（原诗ID）查询所有子内容，筛选匹配 charIndex 的 poem_char
    Content? existingPoemChar;
    try {
      final parentContents = await DatabaseHelper.instance.getContentsByParentId(poemId);
      existingPoemChar = parentContents
          .where((c) => c.type == typePoemChar && c.charIndex == charIndex)
          .firstOrNull;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】查询已有错字Content失败: $e');
      }
      existingPoemChar = null;
    }

    String poemCharId;

    if (existingPoemChar == null) {
      // 步骤3: 创建新的 poem_char 类型Content
      poemCharId = await _createPoemCharContent(
        poemId: poemId,
        charIndex: charIndex,
        standardChar: standardChar,
        fullText: fullText,
      );

      // 步骤4: 为该 poem_char 创建schedule
      await createScheduleForContent(poemCharId);
    } else {
      poemCharId = existingPoemChar.id;
      // 若已存在，重置其schedule为明天复习
      await _resetPoemCharSchedule(poemCharId);
    }

    // 步骤5: 记录到 poem_errors 表
    await _recordPoemError(
      poemId: poemId,
      charIndex: charIndex,
      standardChar: standardChar,
      wrongChar: wrongChar,
    );

    if (kDebugMode) {
      debugPrint('【ScheduleManager】古诗词错字处理完成: poemCharId=$poemCharId');
    }
  }

  /// 更新整首诗的schedule（错字时）
  Future<void> _updatePoemScheduleOnError(String poemId) async {
    try {
      final schedule = await DatabaseHelper.instance.getScheduleByContentId(poemId);
      if (schedule != null) {
        await markAsWrong(poemId, schedule: schedule);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】更新诗词schedule失败: $e');
      }
    }

    if (kDebugMode) {
      debugPrint('【ScheduleManager】更新诗词schedule: poemId=$poemId 按错误处理');
    }
  }

  /// 创建错字类型的Content（poem_char）
  ///
  /// 返回新创建的Content的ID
  Future<String> _createPoemCharContent({
    required String poemId,
    required int charIndex,
    required String standardChar,
    String? fullText,
  }) async {
    // 构建提示信息（古诗词上下文）
    final hint = fullText != null ? '出自: $fullText' : null;

    final poemCharContent = Content(
      content: standardChar,
      type: typePoemChar,
      parentId: poemId,
      charIndex: charIndex,
      fullText: fullText,
      hint: hint,
      source: 'poem_error_extraction',
    );

    // 保存到数据库
    try {
      await DatabaseHelper.instance.insertContent(poemCharContent);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】保存错字Content失败: $e');
      }
      rethrow;
    }

    if (kDebugMode) {
      debugPrint('【ScheduleManager】创建错字Content: ${poemCharContent.toString()}');
    }

    return poemCharContent.id;
  }

  /// 重置已有错字的schedule为明天复习
  Future<void> _resetPoemCharSchedule(String poemCharId) async {
    try {
      final schedule = await DatabaseHelper.instance.getScheduleByContentId(poemCharId);
      if (schedule != null) {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        schedule.nextReviewDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
        schedule.status = statusDifficult;
        await DatabaseHelper.instance.updateSchedule(schedule);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】重置错字schedule失败: $e');
      }
    }

    if (kDebugMode) {
      debugPrint('【ScheduleManager】重置错字schedule: poemCharId=$poemCharId');
    }
  }

  /// 记录错字到 poem_errors 表
  Future<void> _recordPoemError({
    required String poemId,
    required int charIndex,
    required String standardChar,
    String? wrongChar,
  }) async {
    final poemError = PoemError(
      poemId: poemId,
      charIndex: charIndex,
      standardChar: standardChar,
      wrongChar: wrongChar,
      reviewCount: 0,
    );

    // 保存到数据库
    try {
      await DatabaseHelper.instance.insertPoemError(poemError);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】保存错字记录失败: $e');
      }
      // poem_error保存失败不影响主流程，不抛出异常
    }

    if (kDebugMode) {
      debugPrint('【ScheduleManager】记录错字: ${poemError.toString()}');
    }
  }

  // ============================================================
  // 5. 错字复习处理
  // ============================================================

  /// 处理错字（poem_char类型）的复习结果
  ///
  /// 处理流程：
  /// 1. isCorrect=true: consecutiveCorrect +1，检查是否达到3次掌握阈值
  /// 2. isCorrect=false: consecutiveCorrect=0，按错误处理
  /// 3. 连续3次正确后删除 poem_char Content 和 schedule（从薄弱库移除）
  ///
  /// [poemCharId] - 错字Content的ID
  /// [isCorrect] - 本次复习是否正确
  Future<void> reviewPoemChar(String poemCharId, bool isCorrect) async {
    if (kDebugMode) {
      debugPrint('【ScheduleManager】错字复习: poemCharId=$poemCharId, isCorrect=$isCorrect');
    }

    // 从数据库查询该错字的schedule
    Schedule? schedule;
    try {
      schedule = await DatabaseHelper.instance.getScheduleByContentId(poemCharId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】查询错字schedule失败: $e');
      }
      return;
    }

    if (schedule == null) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】reviewPoemChar: 未找到poemCharId=$poemCharId 的schedule');
      }
      return;
    }

    if (isCorrect) {
      // 正确：复用 markAsCorrect 推进间隔和状态
      await markAsCorrect(poemCharId, schedule: schedule);

      // 检查是否达到错字掌握阈值（连续3次正确）
      // 注意：markAsCorrect 内部已增加 consecutiveCorrect
      if (schedule.consecutiveCorrect >= kPoemCharMasterThreshold) {
        // 连续3次正确，从薄弱库移除
        await _removePoemChar(poemCharId);
      }

      // 更新 poem_errors 表的 reviewCount
      await _updatePoemErrorReviewCount(poemCharId);
    } else {
      // 错误：复用 markAsWrong 处理（内部重置连续正确次数、缩短间隔）
      await markAsWrong(poemCharId, schedule: schedule);

      // 更新 poem_errors 表的 reviewCount
      await _updatePoemErrorReviewCount(poemCharId);
    }
  }

  /// 从薄弱库移除错字（连续3次正确后）
  Future<void> _removePoemChar(String poemCharId) async {
    if (kDebugMode) {
      debugPrint('【ScheduleManager】错字连续3次正确，从薄弱库移除: poemCharId=$poemCharId');
    }

    try {
      // 先获取 poem_char Content 信息（删除前需要 parentId 和 charIndex 来更新 poemError）
      final content = await DatabaseHelper.instance.getContentById(poemCharId);

      // 删除对应的schedule
      final schedule = await DatabaseHelper.instance.getScheduleByContentId(poemCharId);
      if (schedule != null) {
        await DatabaseHelper.instance.deleteSchedule(schedule.id);
      }

      // 删除 poem_char 类型的Content
      await DatabaseHelper.instance.deleteContent(poemCharId);

      // 标记 poem_errors 中对应记录（更新 reviewCount）
      if (content != null &&
          content.parentId != null &&
          content.charIndex != null) {
        final poemError = await DatabaseHelper.instance.getPoemErrorByChar(
          content.parentId!,
          content.charIndex!,
        );
        if (poemError != null) {
          // 增加复习次数作为最终复习记录
          poemError.reviewCount += 1;
          await DatabaseHelper.instance.updatePoemError(poemError);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】从薄弱库移除错字失败: $e');
      }
    }
  }

  /// 更新 poem_errors 的 reviewCount
  Future<void> _updatePoemErrorReviewCount(String poemCharId) async {
    try {
      // 获取 poem_char Content 以获取 poemId 和 charIndex
      final content = await DatabaseHelper.instance.getContentById(poemCharId);
      if (content == null) return;
      if (content.parentId == null || content.charIndex == null) return;

      // 根据 poemId 和 charIndex 查询对应的错字记录
      final poemError = await DatabaseHelper.instance.getPoemErrorByChar(
        content.parentId!,
        content.charIndex!,
      );
      if (poemError != null) {
        poemError.reviewCount += 1;
        await DatabaseHelper.instance.updatePoemError(poemError);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】更新错字复习次数失败: $e');
      }
    }
  }

  // ============================================================
  // 6. 数学录音评分处理
  // ============================================================

  /// 处理数学录音的家长评分结果，调整schedule间隔
  ///
  /// 评分影响：
  /// - understood: 间隔延长到14天
  /// - fuzzy: 间隔3天，换表述再抽
  /// - confused: 间隔1天，同类题再抽
  ///
  /// [contentId] - 数学问题内容ID
  /// [rating] - 家长评分：understood / fuzzy / confused
  Future<void> handleMathRating(String contentId, String rating) async {
    // 从数据库查询schedule
    Schedule? schedule;
    try {
      schedule = await DatabaseHelper.instance.getScheduleByContentId(contentId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】数学评分查询schedule失败: $e');
      }
      return;
    }

    if (schedule == null) return;

    int newIntervalDays;

    switch (rating) {
      case kRatingUnderstood:
        // 理解了：间隔延长到14天
        newIntervalDays = 14;
        break;
      case kRatingFuzzy:
        // 有点模糊：间隔3天
        newIntervalDays = 3;
        break;
      case kRatingConfused:
        // 不太懂：间隔1天
        newIntervalDays = 1;
        break;
      default:
        return; // 无效评分，不做处理
    }

    // 更新schedule
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    schedule.intervalDays = newIntervalDays;
    schedule.nextReviewDate = calculateNextReviewDate(today, newIntervalDays);
    schedule.updatedAt = now;

    // 保存到数据库
    try {
      await DatabaseHelper.instance.updateSchedule(schedule);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】数学评分保存schedule失败: $e');
      }
      rethrow;
    }

    if (kDebugMode) {
      debugPrint('【ScheduleManager】数学评分处理: contentId=$contentId, '
          'rating=$rating, newInterval=$newIntervalDays');
    }
  }

  // ============================================================
  // 7. 查询辅助方法
  // ============================================================

  /// 获取所有困难词的schedule列表
  Future<List<Schedule>> getDifficultSchedules() async {
    try {
      return await DatabaseHelper.instance.getDifficultSchedules();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】查询困难词失败: $e');
      }
      return [];
    }
  }

  /// 获取到期需要复习的schedule列表
  Future<List<Schedule>> getDueSchedules({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    try {
      return await DatabaseHelper.instance.getDueSchedules(targetDate);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】查询到期复习项失败: $e');
      }
      return [];
    }
  }

  /// 获取所有新词schedule列表
  Future<List<Schedule>> getNewWordSchedules() async {
    try {
      return await DatabaseHelper.instance.getNewWordSchedules();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】查询新词失败: $e');
      }
      return [];
    }
  }

  /// 根据内容ID获取schedule
  Future<Schedule?> getScheduleByContentId(String contentId) async {
    try {
      return await DatabaseHelper.instance.getScheduleByContentId(contentId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【ScheduleManager】查询schedule失败: $e');
      }
      return null;
    }
  }
}
