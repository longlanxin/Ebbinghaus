import 'package:flutter/material.dart';

/// 语音指令提示条组件
///
/// 在听写页面底部显示的半透明浮动提示条，
/// 展示当前可用的语音指令，帮助孩子了解可以说什么。
///
/// 特点：
/// - 底部悬浮显示，半透明背景
/// - 可自定义显示的指令列表
/// - 简洁的文字提示，适合儿童阅读
/// - 动画滑入效果
///
/// 使用示例：
/// ```dart
/// SpeechHintBar(
///   commands: ['开始', '重复', '慢一点', '我完成了'],
/// )
/// ```
class SpeechHintBar extends StatefulWidget {
  /// 自定义显示的语音指令列表（可选）
  /// 如果未提供，使用默认的常用指令
  final List<String>? commands;

  /// 构造函数
  const SpeechHintBar({
    super.key,
    this.commands,
  });

  @override
  State<SpeechHintBar> createState() => _SpeechHintBarState();
}

class _SpeechHintBarState extends State<SpeechHintBar>
    with SingleTickerProviderStateMixin {
  /// 动画控制器
  late AnimationController _animationController;

  /// 滑入动画
  late Animation<Offset> _slideAnimation;

  /// 默认语音指令列表（听写场景）
  static const List<String> _defaultCommands = [
    '开始',
    '重复',
    '慢一点',
    '我完成了',
  ];

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // 从下往上滑入的动画
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // 从底部外侧开始
      end: Offset.zero, // 滑到正常位置
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // 延迟 1 秒后播放滑入动画
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    // 释放动画控制器资源
    _animationController.dispose();
    super.dispose();
  }

  /// 获取要显示的指令列表
  List<String> get _displayCommands {
    return widget.commands ?? _defaultCommands;
  }

  /// 将指令列表格式化为 "指令1 | 指令2 | 指令3" 的字符串
  String get _hintText {
    return _displayCommands.join('  |  ');
  }

  @override
  Widget build(BuildContext context) {
    // 使用 SlideTransition 实现滑入动画
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        // 外边距：底部留空，左右留空
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16,
        ),
        // 内边距
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        // 半透明深色背景
        decoration: BoxDecoration(
          // 半透明黑色背景（70% 不透明度）
          color: Colors.black.withOpacity(0.7),
          // 圆角
          borderRadius: BorderRadius.circular(24),
          // 微弱阴影
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          // 居中对齐
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 麦克风图标
            const Icon(
              Icons.mic,
              color: Colors.white70,
              size: 18,
            ),
            // 图标与文字间距
            const SizedBox(width: 8),
            // 提示文字
            Flexible(
              child: Text(
                '可以说：$_hintText',
                // 文字样式：白色小字
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'NotoSansSC',
                  color: Colors.white70,
                ),
                // 文字居中
                textAlign: TextAlign.center,
                // 超出自动换行
                softWrap: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
