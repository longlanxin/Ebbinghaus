// lib/screens/report_screen.dart
// 学习报告页面
// 展示今日学习概览、近7天趋势、困难词列表、已掌握统计等

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../utils/constants.dart';

// ============================================================
// ReportScreen - 学习报告页面
// ============================================================

/// 学习报告页面
///
/// 数据展示：
/// - 今日概览：任务数、正确数、错误数、正确率
/// - 近7天趋势：柱状图显示每日正确率
/// - 困难词Top10：错误次数最多的词
/// - 已掌握统计：已学习内容数量
/// - 底部统计：总学习天数、总内容数等
class ReportScreen extends StatefulWidget {
  /// 路由名称
  static const String routeName = '/report';

  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // 数据库助手单例
  final DatabaseHelper _db = DatabaseHelper.instance;

  // 今日统计数据
  Map<String, dynamic> _todayStats = {};

  // 学习统计数据
  Map<String, dynamic> _learningStats = {};

  // 近7天打卡记录
  List<CheckIn> _recentCheckIns = [];

  // 困难词列表
  List<Map<String, dynamic>> _difficultWords = [];

  // 是否正在加载
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 加载所有报告数据
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 并行加载各项数据
      final todayStats = await _db.getTodayStats();
      final learningStats = await _db.getLearningStats();
      final recentCheckIns = await _db.getRecentCheckIns(kRecentCheckInDays);
      final difficultSchedules = await _db.getDifficultSchedules();

      // 获取困难词对应的内容
      final List<Map<String, dynamic>> difficultWords = [];
      // 最多取10个
      for (int i = 0; i < difficultSchedules.length && i < 10; i++) {
        final schedule = difficultSchedules[i];
        final content = await _db.getContentById(schedule.contentId);
        if (content != null) {
          difficultWords.add({
            'content': content,
            'schedule': schedule,
          });
        }
      }

      // 按错误次数降序排序
      difficultWords.sort((a, b) {
        final sA = a['schedule'] as Schedule;
        final sB = b['schedule'] as Schedule;
        return sB.errorCount.compareTo(sA.errorCount);
      });

      setState(() {
        _todayStats = todayStats;
        _learningStats = learningStats;
        _recentCheckIns = recentCheckIns;
        _difficultWords = difficultWords;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载报告数据失败: $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(kBackgroundColor),
      appBar: AppBar(
        title: const Text(
          '学习报告',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(kPrimaryColor),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh, size: 28),
            onPressed: _loadData,
            tooltip: '刷新数据',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(kPrimaryColor)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(kPrimaryColor),
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // ========== 今日概览 ==========
                  _buildTodayOverviewCard(),
                  const SizedBox(height: 20),

                  // ========== 近7天趋势 ==========
                  _buildWeeklyTrendCard(),
                  const SizedBox(height: 20),

                  // ========== 困难词Top10 ==========
                  _buildDifficultWordsCard(),
                  const SizedBox(height: 20),

                  // ========== 已掌握统计 ==========
                  _buildMasteredCard(),
                  const SizedBox(height: 20),

                  // ========== 底部统计 ==========
                  _buildBottomStatsCard(),
                ],
              ),
            ),
    );
  }

  /// 构建今日概览卡片
  Widget _buildTodayOverviewCard() {
    final taskCount = _todayStats['taskCount'] ?? 0;
    final correctCount = _todayStats['correctCount'] ?? 0;
    final wrongCount = _todayStats['wrongCount'] ?? 0;
    final accuracy = taskCount > 0
        ? (correctCount / taskCount * 100).toStringAsFixed(1)
        : '0.0';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.today, color: Color(kPrimaryColor), size: 28),
                SizedBox(width: 8),
                Text(
                  '今日概览',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 4个数据项
            Row(
              children: [
                _buildStatItem(Icons.assignment, Colors.blue, '任务数', '$taskCount'),
                _buildStatItem(Icons.check_circle, Colors.green, '正确数', '$correctCount'),
                _buildStatItem(Icons.cancel, Colors.red, '错误数', '$wrongCount'),
                _buildStatItem(Icons.trending_up, Colors.purple, '正确率', '$accuracy%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建单个统计项
  Widget _buildStatItem(IconData icon, Color color, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(kTextSecondaryColor),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建近7天趋势卡片（柱状图）
  Widget _buildWeeklyTrendCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart, color: Color(kAccentColor), size: 28),
                SizedBox(width: 8),
                Text(
                  '近7天趋势',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: _buildBarChart(),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建柱状图
  Widget _buildBarChart() {
    if (_recentCheckIns.isEmpty) {
      return const Center(
        child: Text(
          '暂无数据',
          style: TextStyle(
            fontSize: 18,
            color: Color(kTextSecondaryColor),
          ),
        ),
      );
    }

    // 准备7天的数据
    final List<CheckIn> chartData = [];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final existing = _recentCheckIns.where((c) {
        return c.date.year == date.year &&
            c.date.month == date.month &&
            c.date.day == date.day;
      }).firstOrNull;
      if (existing != null) {
        chartData.add(existing);
      } else {
        // 没有数据填充空记录
        chartData.add(CheckIn(date: date));
      }
    }

    // 找出最大任务数用于计算比例
    final maxTaskCount = chartData
        .map((c) => c.taskCount)
        .fold<int>(1, (max, c) => c > max ? c : max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: chartData.map((checkIn) {
        final accuracy = checkIn.taskCount > 0
            ? checkIn.correctCount / checkIn.taskCount
            : 0.0;
        final barHeight = checkIn.taskCount > 0
            ? (checkIn.taskCount / maxTaskCount * 100).clamp(10.0, 100.0)
            : 10.0;

        // 根据正确率选择颜色
        Color barColor;
        if (checkIn.taskCount == 0) {
          barColor = Colors.grey[300]!;
        } else if (accuracy >= 0.8) {
          barColor = Colors.green;
        } else if (accuracy >= 0.5) {
          barColor = Colors.orange;
        } else {
          barColor = Colors.red;
        }

        final dateStr = DateFormat('M/d').format(checkIn.date);

        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 正确率文字
              if (checkIn.taskCount > 0)
                Text(
                  '${(accuracy * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                const Text('', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              // 柱子
              Container(
                width: 28,
                height: barHeight.toDouble(),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // 日期标签
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(kTextSecondaryColor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 构建困难词卡片
  Widget _buildDifficultWordsCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: Color(kDifficultColor), size: 28),
                SizedBox(width: 8),
                Text(
                  '困难词（Top 10）',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_difficultWords.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '暂无困难词，太棒了！',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(kTextSecondaryColor),
                    ),
                  ),
                ),
              )
            else
              ..._difficultWords.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final content = data['content'] as Content;
                final schedule = data['schedule'] as Schedule;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      // 排名
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: index < 3 ? const Color(kDifficultColor) : Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: index < 3 ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 内容
                      Expanded(
                        child: Text(
                          content.content,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // 错误次数
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '错误 ${schedule.errorCount} 次',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  /// 构建已掌握统计卡片
  Widget _buildMasteredCard() {
    final masteredCount = _learningStats['masteredCount'] ?? 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '已掌握',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(kTextSecondaryColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$masteredCount 个',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(kPrimaryColor),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.check_circle,
              color: Color(kPrimaryColor),
              size: 40,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建底部统计卡片
  Widget _buildBottomStatsCard() {
    final totalDays = _learningStats['totalDays'] ?? 0;
    final totalContents = _learningStats['totalContents'] ?? 0;
    final totalLearned = _learningStats['totalLearned'] ?? 0;
    final difficultCount = _learningStats['difficultCount'] ?? 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.insights, color: Colors.blue, size: 28),
                SizedBox(width: 8),
                Text(
                  '学习统计',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatRow('总学习天数', '$totalDays 天', Icons.calendar_today, Colors.blue),
            const Divider(height: 20),
            _buildStatRow('总内容数', '$totalContents 个', Icons.library_books, Colors.green),
            const Divider(height: 20),
            _buildStatRow('已学习', '$totalLearned 个', Icons.school, Colors.purple),
            const Divider(height: 20),
            _buildStatRow('困难词数', '$difficultCount 个', Icons.warning, Colors.orange),
          ],
        ),
      ),
    );
  }

  /// 构建统计行
  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              color: Color(kTextPrimaryColor),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(kTextPrimaryColor),
          ),
        ),
      ],
    );
  }
}
