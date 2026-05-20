// lib/screens/difficult_words_screen.dart
// 困难词列表页面
// 展示所有被标记为困难的学习内容，按错误次数降序排列
// 支持长按操作：删除/重置学习记录

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../utils/constants.dart';

// ============================================================
// DifficultWordsScreen - 困难词列表页面
// ============================================================

/// 困难词列表页面
///
/// 数据来源：数据库中status='difficult'的Schedule记录
/// 排序方式：按errorCount降序排列
/// 交互操作：
/// - 长按某项弹出操作菜单
///   - 删除：删除该内容及其学习记录
///   - 重置学习记录：将该内容重置为新词状态
/// 空状态：显示庆祝提示"暂无困难词，太棒了！"
class DifficultWordsScreen extends StatefulWidget {
  /// 路由名称
  static const String routeName = '/difficult_words';

  const DifficultWordsScreen({super.key});

  @override
  State<DifficultWordsScreen> createState() => _DifficultWordsScreenState();
}

class _DifficultWordsScreenState extends State<DifficultWordsScreen> {
  // 数据库助手单例
  final DatabaseHelper _db = DatabaseHelper.instance;

  // 困难词列表（Content + Schedule组合）
  List<Map<String, dynamic>> _difficultWords = [];

  // 是否正在加载
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDifficultWords();
  }

  /// 加载困难词列表
  ///
  /// 1. 查询所有status='difficult'的Schedule
  /// 2. 获取每个Schedule对应的内容
  /// 3. 按errorCount降序排序
  Future<void> _loadDifficultWords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取困难词的schedule列表
      final schedules = await _db.getDifficultSchedules();

      // 获取对应的内容
      final List<Map<String, dynamic>> words = [];
      for (final schedule in schedules) {
        final content = await _db.getContentById(schedule.contentId);
        if (content != null) {
          words.add({
            'content': content,
            'schedule': schedule,
          });
        }
      }

      // 按错误次数降序排序
      words.sort((a, b) {
        final sA = a['schedule'] as Schedule;
        final sB = b['schedule'] as Schedule;
        return sB.errorCount.compareTo(sA.errorCount);
      });

      setState(() {
        _difficultWords = words;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载困难词失败: $e', style: const TextStyle(fontSize: 16)),
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
          '困难词列表',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        // 橙色背景
        backgroundColor: const Color(kAccentColor),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh, size: 28),
            onPressed: _loadDifficultWords,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(kAccentColor)),
              ),
            )
          : _difficultWords.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadDifficultWords,
                  color: const Color(kAccentColor),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12.0),
                    // 困难词数量
                    itemCount: _difficultWords.length,
                    itemBuilder: (context, index) {
                      final data = _difficultWords[index];
                      final content = data['content'] as Content;
                      final schedule = data['schedule'] as Schedule;

                      return _buildDifficultWordCard(content, schedule);
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
          // 庆祝图标
          Icon(
            Icons.celebration,
            size: 80,
            color: Colors.amber[400],
          ),
          const SizedBox(height: 20),
          // 庆祝文字
          const Text(
            '暂无困难词，太棒了！',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(kPrimaryColor),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '继续保持，你做得很好！',
            style: TextStyle(
              fontSize: 18,
              color: Color(kTextSecondaryColor),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建困难词卡片
  Widget _buildDifficultWordCard(Content content, Schedule schedule) {
    // 获取类型显示名称
    final typeDisplayName = kContentTypeDisplayNames[content.type] ?? content.type;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        // 长按弹出操作菜单
        onLongPress: () => _showActionMenu(content, schedule),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // 左侧：内容 + 类型标签
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 内容文字（大字）
                    Text(
                      content.content,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(kTextPrimaryColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 类型标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _getTypeColor(content.type).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        typeDisplayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getTypeColor(content.type),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 右侧：错误次数 + 连续正确次数
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 错误次数（红色）
                  Text(
                    '错误 ${schedule.errorCount} 次',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(kWrongColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 连续正确次数（绿色）
                  Text(
                    '连续正确 ${schedule.consecutiveCorrect} 次',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(kCorrectColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取类型对应颜色
  Color _getTypeColor(String type) {
    switch (type) {
      case typeChineseChar:
      case typeChineseWord:
        return Colors.brown;
      case typeChinesePoem:
        return Colors.purple;
      case typePoemChar:
        return Colors.deepPurple;
      case typeEnglishWord:
      case typeEnglishPhrase:
        return Colors.blue;
      case typeMathQuestion:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// 显示长按操作菜单
  void _showActionMenu(Content content, Schedule schedule) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Text(
                  '操作：${content.content}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                // 重置学习记录按钮
                ListTile(
                  leading: const Icon(
                    Icons.refresh,
                    color: Colors.blue,
                    size: 28,
                  ),
                  title: const Text(
                    '重置学习记录',
                    style: TextStyle(fontSize: 18),
                  ),
                  subtitle: const Text('将该内容重置为新词状态'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _resetLearningProgress(content.id);
                  },
                ),
                const Divider(),
                // 删除按钮
                ListTile(
                  leading: const Icon(
                    Icons.delete,
                    color: Colors.red,
                    size: 28,
                  ),
                  title: const Text(
                    '删除',
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  ),
                  subtitle: const Text('删除该内容及其学习记录'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _confirmDelete(content);
                  },
                ),
                const SizedBox(height: 8),
                // 取消按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: const Color(kTextPrimaryColor),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '取消',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 确认删除对话框
  void _confirmDelete(Content content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '确认删除',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          content: Text(
            '确定要删除"${content.content}"吗？此操作不可恢复！',
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消', style: TextStyle(fontSize: 18)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteContent(content.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('删除', style: TextStyle(fontSize: 18)),
            ),
          ],
        );
      },
    );
  }

  /// 重置学习记录
  ///
  /// 将内容的schedule重置为新词状态
  Future<void> _resetLearningProgress(String contentId) async {
    try {
      final schedule = await _db.getScheduleByContentId(contentId);
      if (schedule != null) {
        // 重置各项状态
        schedule.errorCount = 0;
        schedule.consecutiveCorrect = 0;
        schedule.intervalDays = 0;
        schedule.status = statusNewWord;
        schedule.lastResult = null;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        schedule.nextReviewDate = today;
        schedule.updatedAt = now;

        await _db.updateSchedule(schedule);

        // 刷新列表
        await _loadDifficultWords();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('学习记录已重置', style: TextStyle(fontSize: 16)),
              backgroundColor: Color(kPrimaryColor),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重置失败: $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 删除内容及其学习记录
  Future<void> _deleteContent(String contentId) async {
    try {
      // 删除schedule
      final schedule = await _db.getScheduleByContentId(contentId);
      if (schedule != null) {
        await _db.deleteSchedule(schedule.id);
      }
      // 删除content
      await _db.deleteContent(contentId);

      // 刷新列表
      await _loadDifficultWords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('内容已删除', style: TextStyle(fontSize: 16)),
            backgroundColor: Color(kPrimaryColor),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
