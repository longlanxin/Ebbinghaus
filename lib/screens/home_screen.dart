import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../services/tts_service.dart';

/// 首页 - 主入口页面
/// 显示打卡信息、开始听写大按钮、家长模式和设置入口
/// 适合8岁儿童的极简大按钮设计
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// TTS服务实例，用于播报休息消息
  final TTSService _ttsService = TTSService();

  /// 家长模式长按计时器
  Timer? _parentModeTimer;

  /// 是否正在长按家长模式按钮
  bool _isLongPressing = false;

  /// 家长验证答案输入控制器
  final TextEditingController _verifyController = TextEditingController();

  /// 是否已经播报过休息消息（避免重复播报）
  bool _restMessageSpoken = false;

  @override
  void initState() {
    super.initState();
    _initTTS();
  }

  /// 初始化TTS服务
  Future<void> _initTTS() async {
    await _ttsService.initialize();
  }

  @override
  void dispose() {
    /// 清理计时器和控制器
    _parentModeTimer?.cancel();
    _verifyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// 暖白色背景，护眼配色
      backgroundColor: const Color(0xFFFFF8E1),
      /// 隐藏AppBar，使用PreferredSize.zero
      appBar: PreferredSize(preferredSize: Size.zero, child: AppBar()),
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            /// 计算各类任务数量
            final taskCounts = _calculateTaskCounts(appState.todayTask);
            final bool hasTasks = appState.hasTasks;

            /// 无任务时自动播报休息提示（只播报一次）
            if (!hasTasks && !appState.isLoading && !_restMessageSpoken) {
              _restMessageSpoken = true;
              _speakRestMessage();
            }

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                /// 顶部打卡天数显示区域
                _buildCheckInInfo(appState),

                const SizedBox(height: 20),

                /// 无任务时的休息提示文本
                if (!hasTasks && !appState.isLoading) ...[
                  _buildRestHint(),
                ],

                const Spacer(),

                /// 主按钮区域 - 圆形大按钮
                _buildMainButton(context, appState, hasTasks),

                const SizedBox(height: 24),

                /// 任务量统计显示（仅在有时显示）
                if (hasTasks) _buildTaskCountInfo(taskCounts),

                const Spacer(),

                /// 底部功能入口Row（家长模式 + 设置）
                _buildBottomActions(context),

                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==================== 打卡信息区域 ====================

  /// 构建顶部打卡信息区域
  Widget _buildCheckInInfo(AppState appState) {
    final int streakDays = _calculateStreak(appState);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        /// 小火焰图标，表示连续打卡
        const Icon(
          Icons.local_fire_department,
          color: Colors.orange,
          size: 32,
        ),
        const SizedBox(width: 8),
        Text(
          '已连续打卡$streakDays天',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF212121),
          ),
        ),
      ],
    );
  }

  /// 计算连续打卡天数
  /// 从AppState获取今日打卡记录，如果有则返回连续天数
  int _calculateStreak(AppState appState) {
    if (appState.todayCheckIn == null) return 0;
    /// 有今日打卡记录时返回1（简化实现）
    return 1;
  }

  // ==================== 休息提示区域 ====================

  /// 构建无任务时的休息提示
  Widget _buildRestHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        '今天没有任务，休息一天',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: Colors.orange,
        ),
      ),
    );
  }

  /// TTS播报休息消息
  Future<void> _speakRestMessage() async {
    final bool available = await _ttsService.isAvailable();
    if (available) {
      await _ttsService.speak('今天休息，去外面玩吧');
    }
  }

  // ==================== 主按钮区域 ====================

  /// 构建圆形主按钮
  /// 有任务时显示绿色渐变"开始听写"
  /// 无任务时显示灰色"今天休息"
  Widget _buildMainButton(BuildContext context, AppState appState, bool hasTasks) {
    final double buttonSize = MediaQuery.of(context).size.width * 0.7;

    return GestureDetector(
      onTap: hasTasks
          ? () async {
              /// 开始听写流程
              await appState.startDictation();
              if (context.mounted) {
                Navigator.pushNamed(context, '/dictation');
              }
            }
          : null,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          /// 有任务时绿色渐变，无任务时灰色
          gradient: hasTasks
              ? const LinearGradient(
                  colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: hasTasks ? null : Colors.grey[400],
          /// 有任务时添加阴影效果
          boxShadow: hasTasks
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            hasTasks ? '开始听写' : '今天休息',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: hasTasks ? Colors.white : Colors.white.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 任务量显示区域 ====================

  /// 构建任务量统计信息
  Widget _buildTaskCountInfo(Map<String, int> counts) {
    return Text(
      '语文${counts['chinese'] ?? 0}个 / 英语${counts['english'] ?? 0}个 / 古诗${counts['poem'] ?? 0}首',
      style: const TextStyle(
        fontSize: 16,
        color: Color(0xFF757575),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// 计算各类任务的数量统计
  Map<String, int> _calculateTaskCounts(DailyTask? task) {
    if (task == null) return {'chinese': 0, 'english': 0, 'poem': 0};

    int chinese = 0;
    int english = 0;
    int poem = 0;

    /// 遍历任务列表，按类型分类统计
    for (final item in task.items) {
      final type = item.content.type;
      if (type == typeChineseChar || type == typeChineseWord) {
        chinese++;
      } else if (type == typeChinesePoem) {
        poem++;
      } else if (type == typeEnglishWord || type == typeEnglishPhrase) {
        english++;
      }
    }

    return {'chinese': chinese, 'english': english, 'poem': poem};
  }

  // ==================== 底部操作区域 ====================

  /// 构建底部操作按钮（家长模式 + 设置）
  Widget _buildBottomActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          /// 家长模式按钮（需长按3秒触发验证）
          GestureDetector(
            onLongPressStart: (_) => _onParentModeLongPressStart(context),
            onLongPressEnd: (_) => _onParentModeLongPressEnd(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.admin_panel_settings,
                    color: Color(0xFF757575),
                    size: 20,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '家长模式',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// 设置按钮
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            icon: const Icon(
              Icons.settings,
              color: Color(0xFF757575),
              size: 28,
            ),
            tooltip: '设置',
          ),
        ],
      ),
    );
  }

  /// 家长模式长按开始 - 启动3秒计时器
  void _onParentModeLongPressStart(BuildContext context) {
    _isLongPressing = true;
    _parentModeTimer?.cancel();
    _parentModeTimer = Timer(const Duration(seconds: 3), () {
      if (_isLongPressing && context.mounted) {
        _showParentVerificationDialog(context);
      }
    });
  }

  /// 家长模式长按结束 - 取消计时器
  void _onParentModeLongPressEnd() {
    _isLongPressing = false;
    _parentModeTimer?.cancel();
  }

  /// 显示家长验证弹窗
  /// 需要回答简单的数学题（3+5=?）才能进入家长模式
  void _showParentVerificationDialog(BuildContext context) {
    _verifyController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '家长验证',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '请输入答案：3 + 5 = ?',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _verifyController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                hintText: '输入答案',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '取消',
              style: TextStyle(fontSize: 18),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_verifyController.text.trim() == '8') {
                /// 答案正确，进入家长模式
                Navigator.pop(context);
                Navigator.pushNamed(context, '/parent');
              } else {
                /// 答案错误，显示提示
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('答案错误，请重试'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text(
              '确认',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
