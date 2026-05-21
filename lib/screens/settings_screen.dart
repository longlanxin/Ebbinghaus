// lib/screens/settings_screen.dart
// 设置页面
// 提供TTS语速、每日最大任务数、播报间隔等设置
// 危险区域：清除所有数据（需二次确认）

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';

// ============================================================
// SettingsScreen - 设置页面
// ============================================================

/// 设置页面
///
/// 设置项：
/// - TTS语速：Slider 0.1 ~ 1.0，默认0.5
/// - 每日最大任务数：Slider 5 ~ 30，默认15
/// - 播报间隔(秒)：Slider 3 ~ 10，默认5
///
/// 关于区域：
/// - 关于APP：小蜜蜂记忆助手 v1.0
/// - 艾宾浩斯记忆曲线说明
///
/// 危险区域：
/// - 清除所有数据（红色按钮，AlertDialog二次确认）
class SettingsScreen extends StatefulWidget {
  /// 路由名称
  static const String routeName = '/settings';

  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // SharedPreferences实例
  SharedPreferences? _prefs;

  // 设置值
  double _ttsRate = kDefaultTTSRate;             // TTS语速 0.1 ~ 1.0
  double _maxDailyTasks = kMaxDailyTasks.toDouble(); // 每日最大任务数 5 ~ 30
  double _speakInterval = kAutoAdvanceDelaySeconds.toDouble(); // 播报间隔 3 ~ 10

  // 是否正在加载
  bool _isLoading = true;

  // 设置键名
  static const String _keyTtsRate = 'tts_rate';
  static const String _keyMaxDailyTasks = 'max_daily_tasks';
  static const String _keySpeakInterval = 'speak_interval';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 加载设置
  ///
  /// 从SharedPreferences读取已保存的设置值
  Future<void> _loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      setState(() {
        _ttsRate = _prefs?.getDouble(_keyTtsRate) ?? kDefaultTTSRate;
        _maxDailyTasks = (_prefs?.getInt(_keyMaxDailyTasks) ?? kMaxDailyTasks).toDouble();
        _speakInterval = (_prefs?.getInt(_keySpeakInterval) ?? kAutoAdvanceDelaySeconds).toDouble();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 保存设置
  ///
  /// [key] 设置键名
  /// [value] 设置值（double或int）
  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (value is double) {
        await _prefs!.setDouble(key, value);
      } else if (value is int) {
        await _prefs!.setInt(key, value);
      }
    } catch (e) {
      // 保存失败，忽略
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存设置失败: $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 护眼背景色
      backgroundColor: const Color(kBackgroundColor),
      appBar: AppBar(
        title: const Text(
          '设置',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(kPrimaryColor),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(kPrimaryColor)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // ========== TTS语速设置 ==========
                _buildSliderCard(
                  title: 'TTS语速',
                  subtitle: '当前: ${_ttsRate.toStringAsFixed(1)}',
                  icon: Icons.speed,
                  iconColor: Colors.blue,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  value: _ttsRate,
                  onChanged: (value) {
                    setState(() {
                      _ttsRate = value;
                    });
                    _saveSetting(_keyTtsRate, value);
                  },
                ),
                const SizedBox(height: 12),

                // ========== 每日最大任务数设置 ==========
                _buildSliderCard(
                  title: '每日最大任务数',
                  subtitle: '当前: ${_maxDailyTasks.toInt()}',
                  icon: Icons.format_list_numbered,
                  iconColor: Colors.green,
                  min: 5,
                  max: 30,
                  divisions: 25,
                  value: _maxDailyTasks,
                  onChanged: (value) {
                    setState(() {
                      _maxDailyTasks = value;
                    });
                    _saveSetting(_keyMaxDailyTasks, value.toInt());
                  },
                ),
                const SizedBox(height: 12),

                // ========== 播报间隔时间设置 ==========
                _buildSliderCard(
                  title: '播报间隔(秒)',
                  subtitle: '当前: ${_speakInterval.toInt()}秒',
                  icon: Icons.timer,
                  iconColor: Colors.orange,
                  min: 3,
                  max: 10,
                  divisions: 7,
                  value: _speakInterval,
                  onChanged: (value) {
                    setState(() {
                      _speakInterval = value;
                    });
                    _saveSetting(_keySpeakInterval, value.toInt());
                  },
                ),
                const SizedBox(height: 16),

                // ========== 分隔线 ==========
                const Divider(thickness: 1),
                const SizedBox(height: 8),

                // ========== 关于区域 ==========
                _buildAboutSection(),
                const SizedBox(height: 16),

                // ========== 分隔线 ==========
                const Divider(thickness: 1),
                const SizedBox(height: 16),

                // ========== 危险区域 ==========
                _buildDangerZone(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  /// 构建滑块设置卡片
  ///
  /// [title] 设置项标题
  /// [subtitle] 当前值显示
  /// [icon] 图标
  /// [iconColor] 图标颜色
  /// [min] 最小值
  /// [max] 最大值
  /// [divisions] 分段数
  /// [value] 当前值
  /// [onChanged] 值变化回调
  Widget _buildSliderCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required double min,
    required double max,
    required int divisions,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(kTextPrimaryColor),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(kTextSecondaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 滑块
            Slider(
              min: min,
              max: max,
              divisions: divisions,
              value: value,
              onChanged: onChanged,
              activeColor: iconColor,
              inactiveColor: iconColor.withOpacity(0.2),
              label: value <= 1.0
                  ? value.toStringAsFixed(1)
                  : value.toInt().toString(),
            ),
            // 最小/最大标签
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  min < 1.0 ? min.toStringAsFixed(1) : min.toInt().toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  max < 1.0 ? max.toStringAsFixed(1) : max.toInt().toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建关于区域
  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 24),
              SizedBox(width: 8),
              Text(
                '关于',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(kTextPrimaryColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          child: Column(
            children: [
              // 关于APP
              ListTile(
                leading: const Icon(
                  Icons.app_settings_alt,
                  color: Color(kPrimaryColor),
                  size: 28,
                ),
                title: const Text(
                  '关于',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text(
                  '小蜜蜂记忆助手 v1.0',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(kTextSecondaryColor),
                  ),
                ),
              ),
              const Divider(height: 1),
              // 艾宾浩斯记忆曲线说明
              ListTile(
                leading: const Icon(
                  Icons.psychology,
                  color: Colors.purple,
                  size: 28,
                ),
                title: const Text(
                  '艾宾浩斯记忆曲线',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text(
                  '科学高效的记忆方法',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(kTextSecondaryColor),
                  ),
                ),
                onTap: _showEbbinghausInfo,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 显示艾宾浩斯记忆曲线说明
  void _showEbbinghausInfo() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.psychology, color: Colors.purple, size: 28),
              SizedBox(width: 8),
              Text(
                '艾宾浩斯记忆曲线',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '艾宾浩斯遗忘曲线描述了人类大脑对新事物的遗忘规律。',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '本应用的复习间隔：',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '第1次：当天\n'
                  '第2次：隔天\n'
                  '第3次：第3天\n'
                  '第4次：第7天\n'
                  '第5次：第14天\n'
                  '第6次：第30天\n'
                  '第7次+：每30天',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.8,
                    color: Color(kTextPrimaryColor),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '在遗忘临界点复习，可以事半功倍！',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(kPrimaryColor),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(kPrimaryColor),
              ),
              child: const Text(
                '知道了',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建危险区域
  ///
  /// 红色边框卡片，包含清除所有数据按钮
  /// 点击后弹出AlertDialog二次确认
  Widget _buildDangerZone() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: Colors.red[50],
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red, size: 28),
                  SizedBox(width: 8),
                  Text(
                    '危险区域',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '以下操作不可恢复，请谨慎操作',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              // 清除所有数据按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showClearDataConfirmDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.delete_forever, size: 24),
                  label: const Text(
                    '清除所有数据',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示清除数据确认对话框
  void _showClearDataConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text(
                '确认清除',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          content: const Text(
            '确定要清除所有学习数据吗？\n\n'
            '此操作将删除所有学习内容、学习记录、打卡记录等数据，不可恢复！',
            style: TextStyle(
              fontSize: 18,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '取消',
                style: TextStyle(fontSize: 18),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearAllData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                '确认清除',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 清除所有数据
  ///
  /// 调用DatabaseHelper.clearAllData清除数据库中所有内容
  Future<void> _clearAllData() async {
    try {
      final db = DatabaseHelper.instance;
      await db.clearAllData();

      // 清除SharedPreferences中的设置（可选）
      // _prefs?.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '所有数据已清除',
              style: TextStyle(fontSize: 16),
            ),
            backgroundColor: Color(kPrimaryColor),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '清除数据失败: $e',
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
