import 'package:flutter/material.dart';

/// 大按钮组件
///
/// 专为小学三年级学生设计的大圆角按钮。
/// 特点：
/// - 默认高度 64dp，方便儿童手指点击
/// - 默认文字大小 24sp，加粗，清晰易读
/// - 圆角 16dp，视觉效果友好
/// - 支持自定义颜色、文字大小和高度
///
/// 使用示例：
/// ```dart
/// BigButton(
///   text: '开始听写',
///   onPressed: () => startDictation(),
///   color: Colors.green,
/// )
/// ```
class BigButton extends StatelessWidget {
  /// 按钮上显示的文字
  final String text;

  /// 点击回调函数
  final VoidCallback onPressed;

  /// 按钮背景色（可选，默认使用主题的主色）
  final Color? color;

  /// 文字大小（可选，默认 24sp）
  final double? fontSize;

  /// 按钮高度（可选，默认 64dp）
  final double? height;

  /// 构造函数
  const BigButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.fontSize,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 按钮高度，默认 64dp
      height: height ?? 64,
      // 宽度填满父容器
      width: double.infinity,
      child: ElevatedButton(
        // 点击回调
        onPressed: onPressed,
        // 按钮样式
        style: ElevatedButton.styleFrom(
          // 背景色：优先使用传入的颜色，否则使用主题色
          backgroundColor: color ?? Theme.of(context).primaryColor,
          // 文字颜色：白色，确保在彩色背景上清晰可读
          foregroundColor: Colors.white,
          // 大圆角：16dp
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          // 内边距
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          // 阴影效果
          elevation: 4,
        ),
        child: Text(
          text,
          // 文字样式：大字体、加粗，适合儿童阅读
          style: TextStyle(
            fontSize: fontSize ?? 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSansSC',
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
