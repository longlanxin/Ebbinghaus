import 'package:flutter/material.dart';

/// 护眼容器组件
///
/// 为儿童提供护眼的页面容器，特点：
/// - 默认背景色为暖白色（#FFF8E1），降低蓝光刺激
/// - 自动包裹 SafeArea，避免内容被系统栏遮挡
/// - 支持自定义背景色
/// - 未来可扩展护眼模式（降低蓝光滤镜）
///
/// 使用示例：
/// ```dart
/// EyeProtectionContainer(
///   child: Column(
///     children: [ ... ],
///   ),
/// )
/// ```
class EyeProtectionContainer extends StatelessWidget {
  /// 子组件（页面内容）
  final Widget child;

  /// 背景色（可选，默认暖白色 #FFF8E1）
  final Color? backgroundColor;

  /// 是否启用护眼模式滤镜（可选，默认关闭）
  /// 开启后会在页面叠加一层暖色滤镜，进一步降低蓝光
  final bool eyeProtectionMode;

  /// 构造函数
  const EyeProtectionContainer({
    super.key,
    required this.child,
    this.backgroundColor,
    this.eyeProtectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // 构建基础容器（SafeArea + 背景色）
    Widget container = SafeArea(
      // SafeArea 确保内容不会被刘海屏、底部导航栏等遮挡
      child: Container(
        // 宽度填满屏幕
        width: double.infinity,
        // 高度填满屏幕
        height: double.infinity,
        // 背景色：优先使用传入的颜色，否则使用默认暖白色
        color: backgroundColor ?? const Color(0xFFFFF8E1),
        child: child,
      ),
    );

    // 如果启用了护眼模式，叠加暖色滤镜
    if (eyeProtectionMode) {
      container = Stack(
        children: [
          // 基础容器
          container,
          // 暖色滤镜层：降低蓝光
          Positioned.fill(
            child: IgnorePointer(
              // 忽略指针事件，让点击穿透到下层
              child: Container(
                color: const Color(0x33FF9800), // 半透明橙色滤镜
              ),
            ),
          ),
        ],
      );
    }

    return container;
  }
}
