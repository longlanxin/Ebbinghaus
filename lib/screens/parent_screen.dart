// lib/screens/parent_screen.dart
// 家长模式主页面
// 提供功能入口网格：导入CSV、学习报告、困难词、数学录音评分、设置
// 进入方式：长按首页"家长模式"3秒 + 简单算术验证

import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'import_screen.dart';
import 'report_screen.dart';
import 'difficult_words_screen.dart';
import 'math_recording_screen.dart';
import 'settings_screen.dart';

// ============================================================
// 功能卡片数据模型
// ============================================================

/// 功能卡片信息
class _FeatureCard {
  /// 卡片标题
  final String title;

  /// 卡片图标
  final IconData icon;

  /// 卡片背景色
  final Color color;

  /// 目标页面构建器
  final WidgetBuilder pageBuilder;

  const _FeatureCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.pageBuilder,
  });
}

// ============================================================
// ParentScreen - 家长模式主页面
// ============================================================

/// 家长模式主页面
///
/// 通过网格布局展示5个功能入口卡片：
/// - 导入CSV（绿色）
/// - 学习报告（蓝色）
/// - 困难词列表（橙色）
/// - 数学录音评分（紫色）
/// - 调整任务量/设置（灰色）
///
/// 使用方式：长按首页"家长模式"按钮3秒并通过算术验证后进入
class ParentScreen extends StatelessWidget {
  /// 路由名称
  static const String routeName = '/parent';

  const ParentScreen({super.key});

  // 定义5个功能卡片
  List<_FeatureCard> get _featureCards => [
    _FeatureCard(
      title: '导入CSV',
      icon: Icons.file_upload,
      color: Colors.green,
      pageBuilder: (context) => const ImportScreen(),
    ),
    _FeatureCard(
      title: '学习报告',
      icon: Icons.bar_chart,
      color: Colors.blue,
      pageBuilder: (context) => const ReportScreen(),
    ),
    _FeatureCard(
      title: '困难词列表',
      icon: Icons.warning,
      color: Colors.orange,
      pageBuilder: (context) => const DifficultWordsScreen(),
    ),
    _FeatureCard(
      title: '数学录音评分',
      icon: Icons.mic,
      color: Colors.purple,
      pageBuilder: (context) => const MathRecordingScreen(),
    ),
    _FeatureCard(
      title: '调整任务量',
      icon: Icons.settings,
      color: Colors.grey,
      pageBuilder: (context) => const SettingsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 护眼背景色 - 暖白/米黄
      backgroundColor: const Color(kBackgroundColor),
      appBar: AppBar(
        title: const Text(
          '家长模式',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(kPrimaryColor),
        foregroundColor: Colors.white,
        elevation: 0,
        // 返回按钮自动显示
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          // 每行2列
          crossAxisCount: 2,
          // 宽高比
          childAspectRatio: 1.2,
          // 列间距
          crossAxisSpacing: 12,
          // 行间距
          mainAxisSpacing: 12,
          children: _featureCards.map((card) => _buildFeatureCard(context, card)).toList(),
        ),
      ),
    );
  }

  /// 构建单个功能卡片
  Widget _buildFeatureCard(BuildContext context, _FeatureCard card) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: card.color,
      child: InkWell(
        // 可点击，圆角跟随卡片
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: card.pageBuilder),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          // 垂直居中
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 大图标
            Icon(
              card.icon,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 12),
            // 卡片标题
            Text(
              card.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
