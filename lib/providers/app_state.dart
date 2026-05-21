// lib/providers/app_state.dart
// 全局应用状态管理器
// 使用Provider模式（ChangeNotifier），管理整个APP的核心状态
// 包含：任务加载、听写流程、核对流程、结果提交、CSV导入等

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/content.dart';
import '../models/schedule.dart';
import '../models/check_in.dart';
import '../models/math_recording.dart';
import '../models/daily_task.dart';
import '../services/tts_service.dart';
import '../services/csv_import_service.dart' as csv_service;
import '../utils/constants.dart';
import 'schedule_manager.dart';
import 'task_generator.dart';

// ============================================================
// AppState - 全局应用状态管理器（Provider模式）
// ============================================================

/// 应用听写阶段枚举
enum DictationPhase {
  /// 空闲/首页状态
  idle,

  /// 正在听写（黑屏播报中）
  dictating,

  /// 正在核对（标记正确/错误）
  checking,

  /// 显示结果
  showingResult,

  /// 加载中
  loading,
}

/// 全局应用状态
/// 使用ChangeNotifier实现Provider模式，所有状态变更后调用notifyListeners()
class AppState extends ChangeNotifier {
  // ============================================================
  // 依赖服务（单例模式）
  // ============================================================

  /// 调度管理器
  final ScheduleManager _scheduleManager = ScheduleManager();

  /// 任务生成器
  final TaskGenerator _taskGenerator = TaskGenerator();

  /// 数据库助手单例
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// TTS语音播报服务
  final TTSService _tts = TTSService();

  /// CSV导入服务
  final csv_service.CsvImportService _csvImportService =
      csv_service.CsvImportService();

  // ============================================================
  // 状态字段
  // ============================================================

  /// 是否正在加载数据
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// 当前听写阶段
  DictationPhase _phase = DictationPhase.idle;
  DictationPhase get phase => _phase;

  /// 今日任务（每日生成的学习任务集合）
  DailyTask? _todayTask;
  DailyTask? get todayTask => _todayTask;

  /// 剩余未播报的听写项（听写过程中动态消费）
  List<TaskItem> _remainingItems = [];
  List<TaskItem> get remainingItems => List.unmodifiable(_remainingItems);

  /// 当前正在播报/核对的项索引
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  /// 当前正在播报/核对的项
  TaskItem? get currentItem {
    if (_remainingItems.isNotEmpty && _currentIndex < _remainingItems.length) {
      return _remainingItems[_currentIndex];
    }
    // 如果remainingItems为空但在checkResults中有内容，尝试从todayTask获取
    if (_todayTask != null && _todayTask!.items.isNotEmpty) {
      if (_currentIndex < _todayTask!.items.length) {
        return _todayTask!.items[_currentIndex];
      }
    }
    return null;
  }

  /// 核对结果列表（核对阶段收集用户对每个项的标记）
  final List<CheckResult> _checkResults = [];
  List<CheckResult> get checkResults => List.unmodifiable(_checkResults);

  /// 今日打卡记录
  CheckIn? _todayCheckIn;
  CheckIn? get todayCheckIn => _todayCheckIn;

  /// 统计数据（用于学习报告）
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> get stats => Map.unmodifiable(_stats);

  // ============================================================
  // 计算属性（getter）
  // ============================================================

  /// 是否有任务
  bool get hasTasks => _todayTask != null && _todayTask!.hasTasks;

  /// 是否正在听写
  bool get isDictating => _phase == DictationPhase.dictating;

  /// 是否正在核对
  bool get isChecking => _phase == DictationPhase.checking;

  /// 是否在显示结果
  bool get isShowingResult => _phase == DictationPhase.showingResult;

  /// 是否空闲
  bool get isIdle => _phase == DictationPhase.idle;

  /// 任务总数量
  int get totalTaskCount => _todayTask?.totalCount ?? 0;

  /// 核对进度（已完成核对数/总数）
  int get checkedCount => _checkResults.length;

  /// 正确数量
  int get correctCount => _checkResults.where((r) => r.isCorrect).length;

  /// 错误数量
  int get wrongCount => _checkResults.where((r) => !r.isCorrect).length;

  /// 核对是否全部完成
  bool get isAllChecked {
    if (_todayTask == null) return false;
    return _checkResults.length >= _todayTask!.totalCount;
  }

  /// 连续打卡天数
  int get consecutiveDays => _stats['consecutiveDays'] ?? 0;

  // ============================================================
  // 1. 加载今日任务
  // ============================================================

  /// 加载今日任务
  ///
  /// 调用TaskGenerator生成每日任务列表
  /// 成功后更新 todayTask 状态
  Future<void> loadTodayTask() async {
    _setLoading(true);

    try {
      // 生成每日任务
      _todayTask = await _taskGenerator.generateDailyTask();

      if (kDebugMode) {
        debugPrint('【AppState】今日任务加载完成: ${_todayTask?.toString() ?? "无任务"}');
      }

      // 如果有任务，重置听写状态
      if (_todayTask != null && _todayTask!.hasTasks) {
        _currentIndex = 0;
        _checkResults.clear();
        _remainingItems.clear();
      }

      _phase = DictationPhase.idle;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【AppState】加载今日任务失败: $e');
      }
      _todayTask = DailyTask.empty();
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ============================================================
  // 2. 听写流程控制
  // ============================================================

  /// 开始听写
  ///
  /// 初始化 remainingItems 为 todayTask 的副本
  /// 开始从第一个项播报
  Future<void> startDictation() async {
    if (_todayTask == null || !_todayTask!.hasTasks) {
      if (kDebugMode) {
        debugPrint('【AppState】没有任务，无法开始听写');
      }
      return;
    }

    // 初始化听写状态
    _remainingItems = List.from(_todayTask!.items);
    _currentIndex = 0;
    _checkResults.clear();
    _phase = DictationPhase.dictating;

    if (kDebugMode) {
      debugPrint('【AppState】开始听写，共${_remainingItems.length}项');
    }

    notifyListeners();

    // 播报第一个项
    await _speakCurrentItem();
  }

  /// 播报当前项
  ///
  /// 使用TTS服务播报当前项的内容
  /// 古诗词使用逐句停顿播报方式
  Future<void> _speakCurrentItem() async {
    final item = currentItem;
    if (item == null) return;

    if (kDebugMode) {
      debugPrint('【AppState】播报: ${item.displayText} (类型: ${item.type})');
    }

    // 根据内容类型选择播报方式
    if (item.isPoem) {
      // 古诗词使用逐句停顿播报
      await _tts.speakPoem(item.content.toMap());
    } else {
      // 其他类型使用标准播报
      await _tts.speakContent(item.content.toMap());
    }
  }

  /// 播报下一项
  ///
  /// 移动到下一项并播报
  /// 如果所有项都已播报完毕，自动进入核对模式
  Future<void> nextItem() async {
    if (_phase != DictationPhase.dictating) return;

    // 检查是否还有下一项
    if (_currentIndex < _remainingItems.length - 1) {
      _currentIndex++;
      notifyListeners();
      await _speakCurrentItem();
    } else {
      // 已到最后一个项，播报完成后提示完成
      if (kDebugMode) {
        debugPrint('【AppState】所有项播报完毕');
      }
      // TTS播报"听写完毕，请核对"
      await _tts.speak('听写完毕，请核对');
    }
  }

  /// 重复播报当前项
  ///
  /// 重新播报当前正在听的项（孩子没听清时使用）
  Future<void> repeatItem() async {
    if (_phase != DictationPhase.dictating) return;

    if (kDebugMode) {
      debugPrint('【AppState】重复播报当前项');
    }

    await _speakCurrentItem();
  }

  /// 调整播报语速
  ///
  /// [slower] - true表示变慢，false表示变快
  Future<void> adjustSpeakRate({required bool slower}) async {
    try {
      // 获取当前语速
      final double currentRate = await _tts.getRate();
      final double newRate = slower
          ? (currentRate - 0.1).clamp(0.1, 1.0)
          : (currentRate + 0.1).clamp(0.1, 1.0);
      await _tts.setRate(newRate);

      if (kDebugMode) {
        debugPrint('【AppState】语速调整: ${slower ? "变慢" : "变快"} $currentRate -> $newRate');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【AppState】语速调整失败: $e');
      }
    }

    // 然后重新播报当前项
    await _speakCurrentItem();
  }

  /// 完成听写，进入核对模式
  ///
  /// 切换阶段为 checking，准备开始核对
  Future<void> finishDictation() async {
    if (_phase != DictationPhase.dictating) return;

    // 停止TTS播报
    await _tts.stop();

    // 重置当前索引为0，开始核对第一个
    _currentIndex = 0;
    _phase = DictationPhase.checking;

    if (kDebugMode) {
      debugPrint('【AppState】听写完成，进入核对模式');
    }

    notifyListeners();
  }

  // ============================================================
  // 3. 核对流程控制
  // ============================================================

  /// 标记当前项为正确
  ///
  /// 记录核对结果并自动移动到下一项
  Future<void> markCorrect(String contentId) async {
    if (_phase != DictationPhase.checking) return;

    // 创建正确结果
    final result = CheckResult.correct(contentId);
    _checkResults.add(result);

    if (kDebugMode) {
      debugPrint('【AppState】标记正确: contentId=$contentId');
    }

    notifyListeners();

    // 自动移动到下一项
    await _moveToNextCheckItem();
  }

  /// 标记当前项为错误
  ///
  /// [contentId] - 内容ID
  /// [wrongChar] - 实际写错的字（可选）
  ///
  /// 记录核对结果并自动移动到下一项
  Future<void> markWrong(String contentId, {String? wrongChar}) async {
    if (_phase != DictationPhase.checking) return;

    // 创建错误结果
    final result = CheckResult.wrong(contentId, wrongChar: wrongChar);
    _checkResults.add(result);

    if (kDebugMode) {
      debugPrint('【AppState】标记错误: contentId=$contentId, wrongChar=$wrongChar');
    }

    notifyListeners();

    // 自动移动到下一项
    await _moveToNextCheckItem();
  }

  /// 古诗词逐字核对 - 标记整首诗的核对结果
  ///
  /// [contentId] - 古诗词内容ID
  /// [wrongCharIndices] - 写错字的索引列表 [(charIndex, wrongChar)]
  Future<void> markPoemCheckResult(
    String contentId,
    List<({int charIndex, String? wrongChar})> wrongCharIndices,
  ) async {
    if (_phase != DictationPhase.checking) return;

    // 获取古诗词内容
    final poemItem = _todayTask?.items.firstWhere(
      (item) => item.content.id == contentId,
      orElse: () => throw Exception('未找到古诗词: $contentId'),
    );

    if (poemItem == null) return;

    if (wrongCharIndices.isEmpty) {
      // 全对
      await markCorrect(contentId);
    } else {
      // 有错字，先标记整首诗为错误
      await markWrong(contentId);

      // 然后处理每个错字
      for (final wrongCharInfo in wrongCharIndices) {
        final fullText = poemItem.content.fullText ?? poemItem.content.content;
        if (wrongCharInfo.charIndex >= 0 &&
            wrongCharInfo.charIndex < fullText.length) {
          final standardChar = fullText[wrongCharInfo.charIndex];
          await _scheduleManager.handlePoemCharError(
            contentId,
            wrongCharInfo.charIndex,
            standardChar,
            wrongCharInfo.wrongChar,
            fullText: poemItem.content.fullText,
          );
        }
      }
    }
  }

  /// 移动到下一项核对
  Future<void> _moveToNextCheckItem() async {
    if (_todayTask == null) return;

    // 检查是否还有未核对的项
    if (_currentIndex < _todayTask!.items.length - 1) {
      _currentIndex++;
      notifyListeners();
    } else {
      // 所有项核对完毕，自动提交结果
      if (kDebugMode) {
        debugPrint('【AppState】所有项核对完毕，自动提交');
      }
      await submitCheckResults();
    }
  }

  /// 跳过当前核对项（用户不确定时）
  Future<void> skipCheckItem() async {
    if (_phase != DictationPhase.checking) return;

    // 跳过当前项，不记录结果，直接进入下一项
    await _moveToNextCheckItem();

    if (kDebugMode) {
      debugPrint('【AppState】跳过当前核对项');
    }
  }

  // ============================================================
  // 4. 提交核对结果
  // ============================================================

  /// 提交核对结果
  ///
  /// 处理流程：
  /// 1. 遍历所有核对结果
  /// 2. 正确的项调用 markAsCorrect 更新schedule
  /// 3. 错误的项调用 markAsWrong 更新schedule
  /// 4. 记录打卡
  /// 5. 进入结果展示阶段
  Future<void> submitCheckResults() async {
    if (_checkResults.isEmpty) {
      _phase = DictationPhase.idle;
      notifyListeners();
      return;
    }

    _setLoading(true);

    try {
      int correct = 0;
      int wrong = 0;

      // 处理每个核对结果
      for (final result in _checkResults) {
        // 从数据库获取schedule
        final schedule = await _db.getScheduleByContentId(result.contentId);

        if (result.isCorrect) {
          // 正确处理
          await _scheduleManager.markAsCorrect(
            result.contentId,
            schedule: schedule,
          );
          correct++;
        } else {
          // 错误处理
          await _scheduleManager.markAsWrong(
            result.contentId,
            schedule: schedule,
          );
          wrong++;

          // 如果有错字信息，处理错字
          if (result.wrongChar != null && result.wrongChar!.isNotEmpty) {
            await _handleWrongChar(result.contentId, result.wrongChar!);
          }
        }
      }

      // 记录打卡
      final totalCount = _checkResults.length;
      await _taskGenerator.recordCheckIn(totalCount, correct, wrong);

      // 更新今日打卡记录到状态
      await _loadTodayCheckIn();

      // 进入结果展示阶段
      _phase = DictationPhase.showingResult;

      if (kDebugMode) {
        debugPrint('【AppState】核对结果提交完成: 正确$correct / 错误$wrong');
      }

      // TTS播报结果
      await _tts.speak('听写结束，正确$correct个，错误$wrong个');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【AppState】提交核对结果失败: $e');
      }
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// 处理写错的字
  Future<void> _handleWrongChar(String contentId, String wrongChar) async {
    try {
      // 获取content信息
      final content = await _db.getContentById(contentId);
      if (content != null) {
        // 如果是古诗词，需要处理错字
        if (content.type == typeChinesePoem) {
          // 古诗词错字处理在markPoemCheckResult中统一处理
          // 此处不需要额外操作
          if (kDebugMode) {
            debugPrint('【AppState】古诗词错字: contentId=$contentId, wrongChar=$wrongChar');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【AppState】处理错字失败: $e');
      }
    }
  }

  /// 加载今日打卡记录
  Future<void> _loadTodayCheckIn() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      _todayCheckIn = await _db.getCheckInByDate(today);

      if (kDebugMode) {
        debugPrint('【AppState】今日打卡记录: ${_todayCheckIn?.toString() ?? "无"}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【AppState】加载今日打卡记录失败: $e');
      }
      _todayCheckIn = null;
    }
  }

  // ============================================================
  // 5. 结果页控制
  // ============================================================

  /// 完成结果展示，返回首页
  ///
  /// 清空今日任务，重新加载
  Future<void> finishResult() async {
    _phase = DictationPhase.idle;
    _remainingItems.clear();
    _checkResults.clear();
    _currentIndex = 0;

    // 重新加载今日任务（可能还有剩余任务或第二天的新任务）
    await loadTodayTask();

    if (kDebugMode) {
      debugPrint('【AppState】结果展示完成，返回首页');
    }

    notifyListeners();
  }

  // ============================================================
  // 6. CSV导入
  // ============================================================

  /// 导入CSV文件
  ///
  /// [filePath] - CSV文件路径
  /// 返回导入结果
  Future<ImportResult> importCsv(String filePath) async {
    _setLoading(true);

    try {
      // 调用CSV导入服务进行实际导入
      final csvResult = await _csvImportService.importFromFile(filePath);

      // 将服务层的ImportResult转换为模型层的ImportResult
      final result = ImportResult(
        successCount: csvResult.successCount,
        skipCount: csvResult.skipCount,
        failCount: csvResult.failCount,
        errors: csvResult.errors,
      );

      // 导入成功后，重新加载今日任务（新内容可能纳入今日任务）
      await loadTodayTask();

      if (kDebugMode) {
        debugPrint('【AppState】CSV导入完成: ${result.toString()}');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【AppState】CSV导入失败: $e');
      }
      return ImportResult(
        successCount: 0,
        skipCount: 0,
        failCount: 1,
        errors: ['导入失败: $e'],
      );
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ============================================================
  // 7. 统计数据
  // ============================================================

  /// 加载统计数据
  ///
  /// 加载今日统计、学习统计等数据
  Future<void> loadStats() async {
    _setLoading(true);

    try {
      // 从数据库查询统计数据
      final todayStats = await _db.getTodayStats();
      final learningStats = await _db.getLearningStats();
      final consecutiveDays = await _taskGenerator.getConsecutiveCheckInDays();

      _stats = {
        'todayTaskCount': todayStats['taskCount'] ?? 0,
        'todayCorrectCount': todayStats['correctCount'] ?? 0,
        'todayWrongCount': todayStats['wrongCount'] ?? 0,
        'todayAccuracyRate': todayStats['accuracyRate'] ?? '0.0',
        'todayDurationMinutes': todayStats['durationMinutes'] ?? 0,
        'consecutiveDays': consecutiveDays,
        'totalContents': learningStats['totalContent'] ?? 0,
        'masteredCount': learningStats['masteredCount'] ?? 0,
        'difficultCount': learningStats['difficultCount'] ?? 0,
        'newWordCount': learningStats['newWordCount'] ?? 0,
        'learningCount': learningStats['learningCount'] ?? 0,
        'totalCheckInDays': learningStats['totalCheckInDays'] ?? 0,
        'totalErrors': learningStats['totalErrors'] ?? 0,
      };

      if (kDebugMode) {
        debugPrint('【AppState】统计数据加载完成: $_stats');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【AppState】加载统计数据失败: $e');
      }
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ============================================================
  // 8. 困难词管理
  // ============================================================

  /// 获取困难词列表
  Future<List<Map<String, dynamic>>> getDifficultWords() async {
    try {
      // 查询所有困难词的schedule
      final difficultSchedules = await _db.getDifficultSchedules();
      final List<Map<String, dynamic>> result = [];

      for (final schedule in difficultSchedules) {
        final content = await _db.getContentById(schedule.contentId);
        if (content != null) {
          result.add({
            'content': content,
            'schedule': schedule,
          });
        }
      }

      if (kDebugMode) {
        debugPrint('【AppState】困难词列表: ${result.length}个');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【AppState】查询困难词失败: $e');
      }
      return [];
    }
  }

  /// 重置学习内容的学习记录
  ///
  /// [contentId] - 要重置的内容ID
  Future<void> resetLearningProgress(String contentId) async {
    _setLoading(true);

    try {
      // 查询schedule并重置
      final schedule = await _db.getScheduleByContentId(contentId);
      if (schedule != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // 重置所有学习状态字段
        final resetSchedule = schedule.copyWith(
          intervalDays: 0,
          errorCount: 0,
          consecutiveCorrect: 0,
          status: statusNewWord,
          lastResult: null,
          nextReviewDate: today,
          updatedAt: now,
        );

        await _db.updateSchedule(resetSchedule);
      }

      if (kDebugMode) {
        debugPrint('【AppState】重置学习进度: contentId=$contentId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【AppState】重置学习进度失败: $e');
      }
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// 删除学习内容及其学习记录
  ///
  /// [contentId] - 要删除的内容ID
  Future<void> deleteContent(String contentId) async {
    _setLoading(true);

    try {
      // 删除content（关联的schedule、poem_errors、math_recordings会外键级联删除）
      await _db.deleteContent(contentId);

      // 刷新任务
      await loadTodayTask();

      if (kDebugMode) {
        debugPrint('【AppState】删除内容: contentId=$contentId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【AppState】删除内容失败: $e');
      }
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ============================================================
  // 9. 设置管理
  // ============================================================

  /// 更新设置项
  ///
  /// [key] - 设置键名
  /// [value] - 设置值
  Future<void> updateSetting(String key, dynamic value) async {
    try {
      // 使用SharedPreferences保存设置
      final prefs = await SharedPreferences.getInstance();
      if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }

      if (kDebugMode) {
        debugPrint('【AppState】更新设置: $key = $value');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【AppState】更新设置失败: $e');
      }
    }

    notifyListeners();
  }

  /// 清除所有数据
  ///
  /// 危险操作，清除数据库所有内容和记录
  Future<void> clearAllData() async {
    _setLoading(true);

    try {
      // 清除数据库所有数据
      await _db.clearAllData();

      // 重置状态
      _todayTask = DailyTask.empty();
      _remainingItems.clear();
      _checkResults.clear();
      _currentIndex = 0;
      _phase = DictationPhase.idle;
      _stats = {};
      _todayCheckIn = null;

      if (kDebugMode) {
        debugPrint('【AppState】所有数据已清除');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【AppState】清除数据失败: $e');
      }
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ============================================================
  // 10. 数学录音管理
  // ============================================================

  /// 保存数学录音评分
  ///
  /// [contentId] - 数学问题ID
  /// [rating] - 评分：understood / fuzzy / confused
  Future<void> rateMathRecording(String contentId, String rating) async {
    _setLoading(true);

    try {
      // 更新schedule间隔
      await _scheduleManager.handleMathRating(contentId, rating);

      // 更新MathRecording记录
      final recordings = await _db.getRecordingsByContentId(contentId);
      if (recordings.isNotEmpty) {
        final recording = recordings.first;
        final updatedRecording = recording.copyWith(
          parentRating: rating,
          ratedAt: DateTime.now(),
        );
        await _db.updateMathRecording(updatedRecording);
      }

      if (kDebugMode) {
        debugPrint('【AppState】数学录音评分: contentId=$contentId, rating=$rating');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【AppState】数学录音评分失败: $e');
      }
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// 获取未评分的数学录音列表
  Future<List<MathRecording>> getUnratedMathRecordings() async {
    try {
      final recordings = await _db.getUnratedRecordings();

      if (kDebugMode) {
        debugPrint('【AppState】未评分录音: ${recordings.length}个');
      }

      return recordings;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('【AppState】查询未评分录音失败: $e');
      }
      return [];
    }
  }

  // ============================================================
  // 内部辅助方法
  // ============================================================

  /// 设置加载状态
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// 获取当前项的进度文本（如 "3/15"）
  String getProgressText() {
    if (_todayTask == null || _todayTask!.isEmpty) return '0/0';
    final total = _todayTask!.totalCount;
    if (_phase == DictationPhase.dictating) {
      final current = _currentIndex + 1;
      return '$current/$total';
    } else if (_phase == DictationPhase.checking) {
      final current = _currentIndex + 1;
      return '$current/$total';
    }
    return '0/$total';
  }

  /// 获取当前项的提示文本
  String? getCurrentHint() {
    final item = currentItem;
    if (item == null) return null;

    // 返回提示信息
    return item.content.hint;
  }

  // ============================================================
  // 生命周期管理
  // ============================================================

  @override
  void dispose() {
    // 释放TTS资源
    _tts.stop();

    super.dispose();
  }
}
