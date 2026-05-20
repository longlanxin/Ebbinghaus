import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/models.dart';

/// 结果页面 - 显示听写成绩
/// 居中显示对错数量、困难词提示、打卡信息
/// 3秒后自动返回首页，点击任意位置或按钮立即返回
class ResultScreen extends StatefulWidget {
  const ResultScreen({Key? key}) : super(key: key);

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  /// 自动返回计时器
  Timer? _autoReturnTimer;

  /// 倒计时秒数（从3开始）
  int _countdown = 3;

  /// 是否已经提交过结果
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    /// 启动自动返回倒计时
    _startAutoReturn();
  }

  /// 启动自动返回倒计时
  /// 每秒更新一次UI显示倒计时数字
  void _startAutoReturn() {
    _countdown = 3;
    _autoReturnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
      });

      /// 倒计时结束，自动返回首页
      if (_countdown <= 0) {
        timer.cancel();
        _returnToHome();
      }
    });
  }

  /// 返回首页
  /// 清除导航栈直到回到首页
  void _returnToHome() {
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// 处理手动返回（点击或按钮）
  void _onManualReturn() {
    /// 取消自动计时器
    _autoReturnTimer?.cancel();
    _returnToHome();
  }

  @override
  void dispose() {
    /// 清理计时器
    _autoReturnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// 暖白色背景
      backgroundColor: const Color(0xFFFFF8E1),
      /// 隐藏AppBar
      appBar: PreferredSize(preferredSize: Size.zero, child: AppBar()),
      body: SafeArea(
        child: GestureDetector(
          /// 点击页面任意位置立即返回
          onTap: _onManualReturn,
          child: Consumer<AppState>(
            builder: (context, appState, child) {
              final results = appState.checkResults;

              /// 统计正确和错误数量
              final correctCount = results.where((r) => r.isCorrect).length;
              final wrongCount = results.where((r) => !r.isCorrect).length;

              /// 获取连续打卡天数
              final streakDays = _calculateStreak(appState);

              /// 获取困难词列表（错误的项目）
              final difficultItems = results
                  .where((r) => !r.isCorrect)
                  .map((r) => r.wrongChar)
                  .where((w) => w != null && w.isNotEmpty)
                  .toList();

              /// 计算本次用时（简化实现）
              final int durationMinutes = _calculateDuration(results.length);

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),

                  /// 成绩大数字显示
                  _buildScoreDisplay(correctCount, wrongCount),

                  const SizedBox(height: 32),

                  /// 困难词提示（有错误时显示）
                  if (difficultItems.isNotEmpty)
                    _buildDifficultWords(difficultItems),

                  const SizedBox(height: 24),

                  /// 打卡信息
                  _buildCheckInInfo(streakDays),

                  const SizedBox(height: 12),

                  /// 用时显示
                  _buildDurationInfo(durationMinutes),

                  const Spacer(),

                  /// 倒计时提示文字
                  Text(
                    '$_countdown 秒后自动返回',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// "明天见"主按钮
                  _buildReturnButton(),

                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 构建成绩大数字显示
  /// "对 X / 错 X" 格式，正确绿色，错误红色，中间" / "灰色
  Widget _buildScoreDisplay(int correctCount, int wrongCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        /// 正确数 - 绿色大字
        Text(
          '对 $correctCount',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 16),

        /// 分隔符
        const Text(
          '/',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Color(0xFF757575),
          ),
        ),
        const SizedBox(width: 16),

        /// 错误数 - 红色大字
        Text(
          '错 $wrongCount',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  /// 构建困难词提示卡片
  /// 显示写错的字词列表，帮助孩子重点关注
  Widget _buildDifficultWords(List<String?> difficultItems) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          /// 标题行
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.warning_amber,
                color: Colors.orange,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '需要注意的字词',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          /// 困难词标签列表
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: difficultItems.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 构建打卡信息
  /// 显示火焰图标和连续打卡天数
  Widget _buildCheckInInfo(int streakDays) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.local_fire_department,
          color: Colors.orange,
          size: 28,
        ),
        const SizedBox(width: 8),
        Text(
          '已连续打卡 $streakDays 天',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF212121),
          ),
        ),
      ],
    );
  }

  /// 构建用时信息
  Widget _buildDurationInfo(int durationMinutes) {
    return Text(
      '本次用时 $durationMinutes 分钟',
      style: const TextStyle(
        fontSize: 18,
        color: Color(0xFF757575),
      ),
    );
  }

  /// 构建"明天见"返回按钮
  /// 绿色渐变，64dp高，点击立即返回首页
  Widget _buildReturnButton() {
    return GestureDetector(
      onTap: _onManualReturn,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        height: 64,
        decoration: BoxDecoration(
          /// 绿色渐变背景
          gradient: const LinearGradient(
            colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '明天见',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// 计算连续打卡天数
  int _calculateStreak(AppState appState) {
    if (appState.todayCheckIn == null) return 0;
    /// 简化实现：有今日打卡记录返回1
    return 1;
  }

  /// 计算本次用时（简化估算）
  /// 基于任务数量简单估算
  int _calculateDuration(int taskCount) {
    /// 每项约30秒，加上切换时间
    return (taskCount * 0.5).ceil().clamp(1, 30);
  }
}
