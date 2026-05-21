import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../services/tts_service.dart';

/// 听写黑屏页 - 核心听写界面
/// 全屏黑色背景减少视觉干扰，语音驱动操作
/// 底部半透明浮动条提供三个核心控制按钮
class DictationScreen extends StatefulWidget {
  const DictationScreen({Key? key}) : super(key: key);

  @override
  State<DictationScreen> createState() => _DictationScreenState();
}

class _DictationScreenState extends State<DictationScreen> {
  /// TTS服务实例，用于播报听写内容
  final TTSService _ttsService = TTSService();

  /// 当前TTS语速
  double _currentRate = kDefaultTTSRate;

  /// TTS不可用时是否显示文本回退
  bool _showTextFallback = false;

  /// 语音识别命令订阅
  StreamSubscription<String>? _commandSubscription;

  @override
  void initState() {
    super.initState();
    _initDictation();
  }

  /// 初始化听写环境
  /// 包括初始化TTS、检查TTS可用性、启动语音识别监听、自动播报第一项
  Future<void> _initDictation() async {
    await _ttsService.initialize();
    await _ttsService.setRate(_currentRate);

    /// 检查TTS是否可用
    final bool available = await _ttsService.isAvailable();
    if (!available) {
      setState(() {
        _showTextFallback = true;
      });
    }

    /// 页面初始化后自动播报第一项
    /// 延迟一小段时间确保页面已渲染
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakCurrentItem();
    });
  }

  /// 播报当前听写项
  /// 从 remainingItems 列表中取第一个作为当前项
  Future<void> _speakCurrentItem() async {
    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);
    /// 当前项是 remainingItems 的第一个
    final currentItem = appState.remainingItems.isNotEmpty ? appState.remainingItems.first : null;

    if (currentItem != null) {
      await _ttsService.speakContent(currentItem.content);
    }
  }

  /// 重复播报当前项
  /// 孩子没听清时可以再次播报
  Future<void> _repeatItem() async {
    await _speakCurrentItem();
  }

  /// 降低TTS语速20%
  /// 语速范围限制在0.1-1.0之间
  Future<void> _slowDown() async {
    _currentRate = (_currentRate * 0.8).clamp(0.1, 1.0);
    await _ttsService.setRate(_currentRate);
    /// 降低语速后重新播报当前项
    await _speakCurrentItem();
  }

  /// 完成当前项，进入下一项或导航到核对页
  /// 如果没有更多项，则进入CheckScreen
  Future<void> _finishItem() async {
    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);

    /// 调用AppState进入下一项
    await appState.nextItem();

    /// 检查是否还有剩余项
    if (appState.remainingItems.isEmpty) {
      /// 所有项已完成，结束听写并进入核对页
      await appState.finishDictation();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/check');
      }
    } else {
      /// 还有剩余项，自动播报下一项
      await _speakCurrentItem();
    }
  }

  /// 处理返回键拦截
  /// 弹出确认对话框，防止孩子误触返回
  Future<bool> _onWillPop() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              '确认退出',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              '确定要退出听写吗？当前进度将丢失。',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  '继续听写',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  '退出',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    /// 停止TTS播报
    _ttsService.stop();
    /// 取消语音识别订阅
    _commandSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        /// 纯黑背景，减少视觉干扰，让孩子专注听写
        backgroundColor: Colors.black,
        /// 隐藏AppBar
        appBar: PreferredSize(preferredSize: Size.zero, child: AppBar()),
        body: Stack(
          children: [
            /// 主要内容区域 - 居中显示
            Center(
              child: Consumer<AppState>(
                builder: (context, appState, child) {
                  /// 当前项是 remainingItems 的第一个
                  final currentItem = appState.remainingItems.isNotEmpty ? appState.remainingItems.first : null;
                  final totalItems = appState.todayTask?.items.length ?? 0;
                  /// 计算当前索引（从1开始）
                  final currentIndex = totalItems - appState.remainingItems.length + 1;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      /// 进度显示 - 白色48sp加粗大字
                      Text(
                        '$currentIndex/$totalItems',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),

                      /// 当前内容提示区域
                      if (currentItem != null) ...[
                        /// 古诗词类型特殊显示：标题和作者
                        if (currentItem.content.type == typeChinesePoem) ...[
                          Text(
                            currentItem.content.content,
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentItem.content.hint ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white54,
                            ),
                          ),
                        ] else ...[
                          /// 普通类型的提示文字
                          Text(
                            currentItem.content.hint ?? currentItem.content.content,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],

                      /// TTS不可用时的大字回退显示
                      if (_showTextFallback && currentItem != null) ...[
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            currentItem.content.content,
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),

            /// 底部浮动操作条
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 80,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  /// 半透明白色背景
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    /// 重复按钮 - 黄色图标按钮
                    _buildControlButton(
                      icon: Icons.replay,
                      label: '重复',
                      color: Colors.amber,
                      onPressed: _repeatItem,
                    ),

                    const SizedBox(width: 16),

                    /// 慢一点按钮 - 蓝色图标按钮
                    _buildControlButton(
                      icon: Icons.speed,
                      label: '慢一点',
                      color: Colors.blue,
                      onPressed: _slowDown,
                    ),

                    const SizedBox(width: 16),

                    /// 我完成了按钮 - 绿色大按钮
                    Expanded(
                      child: GestureDetector(
                        onTap: _finishItem,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 28,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '我完成了',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建底部控制按钮（重复 / 慢一点）
  /// 圆形图标按钮，带有标签文字
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color.withOpacity(0.8),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
