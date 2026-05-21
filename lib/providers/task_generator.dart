// lib/providers/task_generator.dart
// 每日任务生成器
// 核心算法：按优先级生成每日学习任务列表
// 优先级：困难词加练 > 到期复习 > 新学内容 > 数学抽查

import 'dart:math';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/content.dart';
import '../models/schedule.dart';
import '../models/check_in.dart';
import '../models/daily_task.dart';
import '../utils/constants.dart';
import '../utils/ebbinghaus.dart';

// ============================================================
// TaskGenerator - 每日任务生成核心类
// ============================================================

/// 每日任务生成器
/// 根据艾宾浩斯调度算法生成优先级的学习任务列表
/// 总量不超过 kMaxDailyTasks（默认15个）
class TaskGenerator {
  // 单例模式
  static final TaskGenerator _instance = TaskGenerator._internal();
  factory TaskGenerator() => _instance;
  TaskGenerator._internal();

  // 随机数生成器（用于数学抽查随机选择）
  final Random _random = Random();

  // ============================================================
  // 核心算法：生成每日任务
  // ============================================================

  /// 生成每日学习任务列表
  ///
  /// 生成优先级（从高到低）：
  /// 1. 困难词加练（status='difficult'，最多kMaxDifficultWords=3个）
  ///    - 优先选择 errorCount 高的
  /// 2. 到期复习项（nextReviewDate <= today，status != 'mastered'）
  ///    - 优先选择 errorCount 高的
  /// 3. 新学内容（intervalDays == 0，status='new_word'）
  ///    - 按创建时间排序（先创建的先学）
  /// 4. 数学抽查（本周已抽查 < 2次，随机1道）
  ///
  /// 总量不超过 kMaxDailyTasks（默认15个）
  ///
  /// 返回 DailyTask 对象，包含所有任务项
  Future<DailyTask> generateDailyTask() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<TaskItem> taskItems = [];

    if (kDebugMode) {
      debugPrint('【TaskGenerator】开始生成每日任务...');
    }

    // ========== 步骤1: 收集困难词加练（最高优先级）==========
    final difficultItems = await _collectDifficultWords(today);
    taskItems.addAll(difficultItems);
    if (kDebugMode) {
      debugPrint('【TaskGenerator】困难词: ${difficultItems.length}个');
    }

    // ========== 步骤2: 收集到期复习项 ==========
    final dueItems = await _collectDueReviews(today, taskItems);
    taskItems.addAll(dueItems);
    if (kDebugMode) {
      debugPrint('【TaskGenerator】到期复习: ${dueItems.length}个');
    }

    // ========== 步骤3: 收集新学内容 ==========
    final newItems = await _collectNewWords(today, taskItems);
    taskItems.addAll(newItems);
    if (kDebugMode) {
      debugPrint('【TaskGenerator】新学内容: ${newItems.length}个');
    }

    // ========== 步骤4: 数学抽查 ==========
    bool hasMathQuiz = false;
    final remainingSlots = kMaxDailyTasks - taskItems.length;
    if (remainingSlots > 0) {
      final shouldIncludeMath = await _shouldIncludeMathQuiz();
      if (shouldIncludeMath) {
        final mathItem = await _selectMathQuiz(taskItems);
        if (mathItem != null) {
          taskItems.add(mathItem);
          hasMathQuiz = true;
          if (kDebugMode) {
            debugPrint('【TaskGenerator】数学抽查: 1个');
          }
        }
      }
    }

    // ========== 步骤5: 按优先级排序 ==========
    _sortTaskItems(taskItems);

    // ========== 步骤6: 截断到最大任务数 ==========
    final finalItems = _limitTaskCount(taskItems, kMaxDailyTasks);

    // 构建 DailyTask 结果
    final dailyTask = DailyTask(
      items: finalItems,
      date: today,
      hasMathQuiz: hasMathQuiz,
    );

    if (kDebugMode) {
      debugPrint('【TaskGenerator】每日任务生成完成: ${dailyTask.toString()}');
    }

    return dailyTask;
  }

  // ============================================================
  // 步骤1: 收集困难词加练
  // ============================================================

  /// 收集困难词任务项（status='difficult'）
  ///
  /// 规则：
  /// - 选择status='difficult'的schedule
  /// - 最多取 kMaxDifficultWords=3 个
  /// - 按 errorCount 降序排列（错误多的优先）
  /// - 排除已经在今日任务中的内容
  Future<List<TaskItem>> _collectDifficultWords(DateTime today) async {
    final List<TaskItem> items = [];

    // 从数据库查询困难词schedule
    final difficultSchedules = await DatabaseHelper.instance.getDifficultSchedules();

    // 按 errorCount 降序排列
    difficultSchedules.sort((a, b) => b.errorCount.compareTo(a.errorCount));

    int count = 0;
    for (final schedule in difficultSchedules) {
      if (count >= kMaxDifficultWords) break;

      // 获取关联的Content
      final content = await DatabaseHelper.instance.getContentById(schedule.contentId);
      if (content != null) {
        items.add(TaskItem(
          content: content,
          schedule: schedule,
          isNew: false,
          isDifficult: true,
        ));
        count++;
      }
    }

    return items;
  }

  // ============================================================
  // 步骤2: 收集到期复习项
  // ============================================================

  /// 收集到期需要复习的任务项
  ///
  /// 规则：
  /// - nextReviewDate <= today（已经到期）
  /// - status != 'mastered'（已掌握的不需要复习）
  /// - 按 errorCount 降序排列（容易错的多复习）
  /// - 排除已经在今日任务中的内容
  Future<List<TaskItem>> _collectDueReviews(
    DateTime today,
    List<TaskItem> existingItems,
  ) async {
    final List<TaskItem> items = [];

    // 从数据库查询到期schedule
    final dueSchedules = await DatabaseHelper.instance.getDueSchedules(today);

    // 过滤掉已掌握的、已在任务列表中的、以及困难词（困难词已单独处理）
    final existingContentIds = existingItems.map((item) => item.content.id).toSet();

    final filteredSchedules = dueSchedules.where((schedule) {
      // 排除已掌握的
      if (schedule.status == statusMastered) return false;
      // 排除已在列表中的
      if (existingContentIds.contains(schedule.contentId)) return false;
      // 排除困难词（已在步骤1处理）
      if (schedule.status == statusDifficult) return false;
      return true;
    }).toList();

    // 按 errorCount 降序排列（错误多的优先复习）
    filteredSchedules.sort((a, b) => b.errorCount.compareTo(a.errorCount));

    for (final schedule in filteredSchedules) {
      // 获取关联的Content
      final content = await DatabaseHelper.instance.getContentById(schedule.contentId);
      if (content != null && content.type != typeMathQuestion) {
        items.add(TaskItem(
          content: content,
          schedule: schedule,
          isNew: false,
          isDifficult: false,
        ));
      }
    }

    return items;
  }

  // ============================================================
  // 步骤3: 收集新学内容
  // ============================================================

  /// 收集新学内容任务项
  ///
  /// 规则：
  /// - intervalDays == 0（尚未开始学习）
  /// - status == 'new_word'
  /// - 按创建时间排序（先创建的先学）
  /// - 排除已经在今日任务中的内容
  Future<List<TaskItem>> _collectNewWords(
    DateTime today,
    List<TaskItem> existingItems,
  ) async {
    final List<TaskItem> items = [];

    // 从数据库查询新词schedule
    final newWordSchedules = await DatabaseHelper.instance.getNewWordSchedules();

    // 排除已在任务列表中的
    final existingContentIds = existingItems.map((item) => item.content.id).toSet();

    final filteredSchedules = newWordSchedules.where((schedule) {
      if (existingContentIds.contains(schedule.contentId)) return false;
      return true;
    }).toList();

    // 按创建时间排序（先创建的先学）
    filteredSchedules.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final schedule in filteredSchedules) {
      // 获取关联的Content
      final content = await DatabaseHelper.instance.getContentById(schedule.contentId);
      if (content != null && content.type != typeMathQuestion) {
        items.add(TaskItem(
          content: content,
          schedule: schedule,
          isNew: true,
          isDifficult: false,
        ));
      }
    }

    return items;
  }

  // ============================================================
  // 步骤4: 数学抽查
  // ============================================================

  /// 判断本周是否还需要数学抽查
  ///
  /// 规则：本周数学抽查次数 < kMathQuizzesPerWeek(2次)
  ///
  /// 注意：此处为简化实现，通过查询本周打卡记录数来近似判断
  /// （DatabaseHelper中没有直接的getMathQuizCountBetween方法）
  Future<bool> _shouldIncludeMathQuiz() async {
    try {
      // 计算本周开始日期
      final weekStart = _getWeekStart(DateTime.now());
      final weekStartMillis = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      ).millisecondsSinceEpoch;

      // 查询最近7天的打卡记录
      final recentCheckIns = await DatabaseHelper.instance.getRecentCheckIns(7);

      // 统计本周（从周一开始）的打卡天数
      final thisWeekCheckIns = recentCheckIns.where((checkIn) {
        final checkInDateMillis = DateTime(
          checkIn.date.year,
          checkIn.date.month,
          checkIn.date.day,
        ).millisecondsSinceEpoch;
        return checkInDateMillis >= weekStartMillis;
      }).toList();

      // 简化实现：以本周打卡天数作为是否包含数学抽查的依据
      // 如果本周已有足够多次打卡，则认为已包含过数学抽查
      return thisWeekCheckIns.length < kMathQuizzesPerWeek;
    } catch (e) {
      // 查询失败时默认包含数学抽查
      if (kDebugMode) {
        debugPrint('【TaskGenerator】判断数学抽查失败: $e，默认包含');
      }
      return true;
    }
  }

  /// 随机选择一道数学问题
  ///
  /// [existingItems] - 已有任务项（用于排除已在列表中的）
  /// 返回选中的数学问题TaskItem，如果没有可用问题则返回null
  Future<TaskItem?> _selectMathQuiz(List<TaskItem> existingItems) async {
    // 从数据库查询所有math_question类型的Content
    final mathContents = await DatabaseHelper.instance.getContentsByType(typeMathQuestion);

    if (mathContents.isEmpty) return null;

    // 排除已在任务列表中的
    final existingContentIds = existingItems.map((item) => item.content.id).toSet();
    final availableMathContents = mathContents
        .where((content) => !existingContentIds.contains(content.id))
        .toList();

    if (availableMathContents.isEmpty) return null;

    // 随机选择一道题
    final selectedContent = availableMathContents[_random.nextInt(availableMathContents.length)];

    // 为数学题创建临时schedule（数学不纳入艾宾浩斯循环，使用特殊逻辑）
    final tempSchedule = Schedule(
      contentId: selectedContent.id,
      nextReviewDate: DateTime.now(),
      intervalDays: 0,
      status: statusLearning,
    );

    return TaskItem(
      content: selectedContent,
      schedule: tempSchedule,
      isNew: false,
      isDifficult: false,
    );
  }

  // ============================================================
  // 辅助方法
  // ============================================================

  /// 获取本周开始日期（周一）
  DateTime _getWeekStart(DateTime date) {
    // weekday: 周一=1, 周日=7
    final daysSinceMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: daysSinceMonday));
  }

  /// 任务项排序
  /// 排序规则：
  /// 1. 困难词排在最前面
  /// 2. 到期复习排在中间（按errorCount降序）
  /// 3. 新学内容排在最后
  void _sortTaskItems(List<TaskItem> items) {
    items.sort((a, b) {
      // 困难词优先
      if (a.isDifficult && !b.isDifficult) return -1;
      if (!a.isDifficult && b.isDifficult) return 1;

      // 到期复习优先于新词
      if (!a.isNew && b.isNew) return -1;
      if (a.isNew && !b.isNew) return 1;

      // 同类型中按errorCount降序
      final errorCompare = b.schedule.errorCount.compareTo(a.schedule.errorCount);
      if (errorCompare != 0) return errorCompare;

      // 最后按nextReviewDate升序（先到期的先复习）
      return a.schedule.nextReviewDate.compareTo(b.schedule.nextReviewDate);
    });
  }

  /// 限制任务数量到最大值
  List<TaskItem> _limitTaskCount(List<TaskItem> items, int maxCount) {
    if (items.length <= maxCount) return items;

    final limitedItems = items.sublist(0, maxCount);

    // 如果被截断，确保至少包含所有困难词（如果困难词数<=maxCount）
    // 这个逻辑在上面排序后已经自然满足

    if (kDebugMode) {
      debugPrint('【TaskGenerator】任务数量截断: ${items.length} -> $maxCount');
    }

    return limitedItems;
  }

  // ============================================================
  // 打卡记录
  // ============================================================

  /// 记录每日打卡
  ///
  /// [taskCount] - 当日任务总数
  /// [correctCount] - 当日正确数
  /// [wrongCount] - 当日错误数
  Future<void> recordCheckIn(int taskCount, int correctCount, int wrongCount) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      // 检查今天是否已有打卡记录
      final existingCheckIn = await DatabaseHelper.instance.getCheckInByDate(today);

      if (existingCheckIn != null) {
        // 更新已有记录
        final updatedCheckIn = existingCheckIn.copyWith(
          taskCount: taskCount,
          correctCount: correctCount,
          wrongCount: wrongCount,
        );
        await DatabaseHelper.instance.updateCheckIn(updatedCheckIn);
      } else {
        // 创建新记录
        final checkIn = CheckIn(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          date: today,
          taskCount: taskCount,
          correctCount: correctCount,
          wrongCount: wrongCount,
        );
        await DatabaseHelper.instance.insertCheckIn(checkIn);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【TaskGenerator】打卡记录保存失败: $e');
      }
    }

    if (kDebugMode) {
      debugPrint('【TaskGenerator】打卡记录: 任务$taskCount, 正确$correctCount, 错误$wrongCount');
    }
  }

  /// 获取连续打卡天数
  ///
  /// 查询最近30天打卡记录，从今天往前数，找到连续的天数
  Future<int> getConsecutiveCheckInDays() async {
    try {
      // 查询最近30天的打卡记录
      final recentCheckIns = await DatabaseHelper.instance.getRecentCheckIns(30);

      if (recentCheckIns.isEmpty) {
        return 0;
      }

      // 将打卡记录按日期转换为Set（便于快速查找）
      final checkInDates = <int>{};
      for (final checkIn in recentCheckIns) {
        final dateKey = DateTime(
          checkIn.date.year,
          checkIn.date.month,
          checkIn.date.day,
        ).millisecondsSinceEpoch;
        checkInDates.add(dateKey);
      }

      // 从今天往前数，找到连续的天数
      int consecutiveDays = 0;
      DateTime currentDate = DateTime.now();

      // 检查今天是否有打卡（今天还没结束，可能有也可能没有）
      // 从昨天开始往前数更合理
      currentDate = currentDate.subtract(const Duration(days: 1));

      while (true) {
        final dateKey = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
        ).millisecondsSinceEpoch;

        if (checkInDates.contains(dateKey)) {
          consecutiveDays++;
          currentDate = currentDate.subtract(const Duration(days: 1));
        } else {
          // 找到中断日期，退出循环
          break;
        }

        // 防止无限循环（最多查30天）
        if (consecutiveDays >= 30) {
          break;
        }
      }

      // 检查今天是否有打卡，如果有则加1
      final todayKey = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ).millisecondsSinceEpoch;
      if (checkInDates.contains(todayKey)) {
        consecutiveDays++;
      }

      return consecutiveDays;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【TaskGenerator】计算连续打卡天数失败: $e');
      }
      return 0;
    }
  }
}
