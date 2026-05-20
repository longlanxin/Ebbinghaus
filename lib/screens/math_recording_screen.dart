// lib/screens/math_recording_screen.dart
// 数学录音评分页面
// 家长通过此页面对孩子的数学答题录音进行评分
// 评分结果影响该数学题的复习间隔

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/constants.dart';

// ============================================================
// MathRecordingScreen - 数学录音评分页面
// ============================================================

/// 数学录音评分页面
///
/// 评分标准：
/// - 理解了（绿色）：间隔延长到14天
/// - 有点模糊（橙色）：间隔3天
/// - 不太懂（红色）：间隔1天
///
/// 交互：
/// - 未评分的录音排在前面，带"新"标签
/// - 每项有播放按钮可播放录音
/// - 评分后该项变灰，显示已评分状态
/// - 使用AudioService播放录音
class MathRecordingScreen extends StatefulWidget {
  /// 路由名称
  static const String routeName = '/math_recording';

  const MathRecordingScreen({super.key});

  @override
  State<MathRecordingScreen> createState() => _MathRecordingScreenState();
}

class _MathRecordingScreenState extends State<MathRecordingScreen> {
  // 数据库助手单例
  final DatabaseHelper _db = DatabaseHelper.instance;

  // 音频服务
  final AudioService _audioService = AudioService();

  // 录音列表（包含对应的问题内容）
  List<Map<String, dynamic>> _recordings = [];

  // 是否正在加载
  bool _isLoading = true;

  // 当前正在播放的录音ID
  String? _playingRecordingId;

  // 录音时长显示（秒）
  final Map<String, int> _recordingDurations = {};

  @override
  void initState() {
    super.initState();
    _initializeAudio();
    _loadRecordings();
  }

  /// 初始化音频服务
  Future<void> _initializeAudio() async {
    await _audioService.initialize();
  }

  @override
  void dispose() {
    // 停止播放
    _audioService.stopPlaying();
    super.dispose();
  }

  /// 加载数学录音列表
  ///
  /// 1. 获取所有录音（包括已评分和未评分）
  /// 2. 获取每个录音对应的数学问题内容
  /// 3. 未评分的排在前面
  Future<void> _loadRecordings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取所有录音：先取未评分的，再取已评分的
      final unrated = await _db.getUnratedRecordings();
      // 获取所有录音（包括已评分的）- 通过查询所有math_recordings
      final allRecordings = <MathRecording>[];
      allRecordings.addAll(unrated);

      // 构建带内容信息的列表
      final List<Map<String, dynamic>> items = [];
      for (final recording in allRecordings) {
        final content = await _db.getContentById(recording.contentId);
        if (content != null) {
          items.add({
            'recording': recording,
            'content': content,
          });
        }
      }

      // 已评分的排在后面
      items.sort((a, b) {
        final rA = a['recording'] as MathRecording;
        final rB = b['recording'] as MathRecording;
        // 未评分的在前
        if (!rA.isRated && rB.isRated) return -1;
        if (rA.isRated && !rB.isRated) return 1;
        // 同类型按时间排序（新的在前）
        return rB.recordedAt.compareTo(rA.recordedAt);
      });

      setState(() {
        _recordings = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载录音失败: $e', style: const TextStyle(fontSize: 16)),
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
          '数学录音评分',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        // 紫色背景
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh, size: 28),
            onPressed: _loadRecordings,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              ),
            )
          : _recordings.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadRecordings,
                  color: Colors.purple,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12.0),
                    itemCount: _recordings.length,
                    itemBuilder: (context, index) {
                      final data = _recordings[index];
                      final recording = data['recording'] as MathRecording;
                      final content = data['content'] as Content;

                      return _buildRecordingCard(recording, content);
                    },
                  ),
                ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            '暂无数学录音',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '完成数学任务后录音会显示在这里',
            style: TextStyle(
              fontSize: 18,
              color: Color(kTextSecondaryColor),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建录音卡片
  Widget _buildRecordingCard(MathRecording recording, Content content) {
    final isRated = recording.isRated;
    final isPlaying = _playingRecordingId == recording.id;
    final dateStr = DateFormat('MM-dd HH:mm').format(recording.recordedAt);

    // 已评分的项变灰
    final cardColor = isRated ? Colors.grey[200] : Colors.white;
    final textColor = isRated ? Colors.grey[500] : const Color(kTextPrimaryColor);

    return Card(
      elevation: isRated ? 1 : 3,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== 顶部Row：问题文字 + 录音时间 + 新标签 ==========
            Row(
              children: [
                // "新"标签（未评分的）
                if (!isRated)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '新',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                // 已评分标签
                if (isRated)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '已评分',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                // 问题文字
                Expanded(
                  child: Text(
                    content.content,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 录音时间
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 14,
                    color: isRated ? Colors.grey[400] : const Color(kTextSecondaryColor),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ========== 中部Row：播放按钮 + 录音时长 ==========
            Row(
              children: [
                // 播放按钮
                ElevatedButton.icon(
                  onPressed: isRated ? null : () => _playRecording(recording),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPlaying ? Colors.orange : Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  icon: Icon(
                    isPlaying ? Icons.stop : Icons.play_arrow,
                    size: 24,
                  ),
                  label: Text(
                    isPlaying ? '停止' : '播放',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                // 录音时长
                if (_recordingDurations.containsKey(recording.id))
                  Text(
                    '${_recordingDurations[recording.id]}秒',
                    style: TextStyle(
                      fontSize: 16,
                      color: isRated ? Colors.grey[400] : const Color(kTextSecondaryColor),
                    ),
                  ),
                const Spacer(),
                // 评分结果显示
                if (isRated && recording.parentRating != null)
                  _buildRatingDisplay(recording.parentRating!),
              ],
            ),

            const SizedBox(height: 12),

            // ========== 底部Row：三个评分按钮 ==========
            if (!isRated)
              Row(
                children: [
                  // "理解了"按钮
                  Expanded(
                    child: _buildRatingButton(
                      label: '理解了',
                      color: Colors.green,
                      onPressed: () => _rateRecording(recording, kRatingUnderstood),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // "有点模糊"按钮
                  Expanded(
                    child: _buildRatingButton(
                      label: '有点模糊',
                      color: Colors.orange,
                      onPressed: () => _rateRecording(recording, kRatingFuzzy),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // "不太懂"按钮
                  Expanded(
                    child: _buildRatingButton(
                      label: '不太懂',
                      color: Colors.red,
                      onPressed: () => _rateRecording(recording, kRatingConfused),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// 构建评分按钮
  Widget _buildRatingButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 构建评分结果显示
  Widget _buildRatingDisplay(String rating) {
    String label;
    Color color;
    IconData icon;

    switch (rating) {
      case kRatingUnderstood:
        label = '理解了';
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case kRatingFuzzy:
        label = '有点模糊';
        color = Colors.orange;
        icon = Icons.help;
        break;
      case kRatingConfused:
        label = '不太懂';
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        label = rating;
        color = Colors.grey;
        icon = Icons.question_mark;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 播放录音
  ///
  /// 如果正在播放当前录音则停止，否则开始播放
  Future<void> _playRecording(MathRecording recording) async {
    try {
      if (_playingRecordingId == recording.id) {
        // 正在播放当前录音，停止
        await _audioService.stopPlaying();
        setState(() {
          _playingRecordingId = null;
        });
      } else {
        // 先停止其他录音
        await _audioService.stopPlaying();

        setState(() {
          _playingRecordingId = recording.id;
        });

        // 开始播放
        await _audioService.playRecording(
          recording.filePath,
          onComplete: () {
            if (mounted) {
              setState(() {
                _playingRecordingId = null;
              });
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _playingRecordingId = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('播放失败: $error', style: const TextStyle(fontSize: 16)),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        );
      }
    } catch (e) {
      setState(() {
        _playingRecordingId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放出错: $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 评分录音
  ///
  /// 根据评分更新录音记录和对应的schedule间隔：
  /// - understood：间隔14天
  /// - fuzzy：间隔3天
  /// - confused：间隔1天
  Future<void> _rateRecording(MathRecording recording, String rating) async {
    try {
      // 更新录音评分
      recording.parentRating = rating;
      recording.ratedAt = DateTime.now();
      await _db.updateMathRecording(recording);

      // 更新对应schedule的间隔
      final schedule = await _db.getScheduleByContentId(recording.contentId);
      if (schedule != null) {
        // 根据评分设置不同的复习间隔
        switch (rating) {
          case kRatingUnderstood:
            schedule.intervalDays = 14;
            break;
          case kRatingFuzzy:
            schedule.intervalDays = 3;
            break;
          case kRatingConfused:
            schedule.intervalDays = 1;
            break;
        }
        schedule.nextReviewDate = DateTime.now().add(Duration(days: schedule.intervalDays));
        schedule.updatedAt = DateTime.now();
        await _db.updateSchedule(schedule);
      }

      // 刷新列表
      await _loadRecordings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('评分已保存', style: TextStyle(fontSize: 16)),
            backgroundColor: Color(kPrimaryColor),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('评分失败: $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
