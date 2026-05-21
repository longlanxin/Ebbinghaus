import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../utils/constants.dart';

/// 通用核对页
/// 显示所有听写项的核对列表，每项有"对"/"错"两个大按钮
/// 古诗词类型额外提供"逐字核对"入口
/// 底部有蓝色大提交按钮
class CheckScreen extends StatefulWidget {
  const CheckScreen({Key? key}) : super(key: key);

  @override
  State<CheckScreen> createState() => _CheckScreenState();
}

class _CheckScreenState extends State<CheckScreen> {
  /// 记录每题正在播放缩放动画的状态（contentId -> bool）
  final Map<String, bool> _scalingItems = {};

  /// 错字输入控制器
  final TextEditingController _wrongCharController = TextEditingController();

  @override
  void dispose() {
    _wrongCharController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// 暖白色背景
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        title: const Text(
          '核对结果',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        /// AppBar绿色背景
        backgroundColor: Colors.green,
        centerTitle: true,
        elevation: 0,
        /// 隐藏返回按钮，防止误触返回
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            final results = appState.checkResults;
            final items = appState.todayTask?.items ?? [];

            return Column(
              children: [
                /// 核对列表区域
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final content = item.content;

                      /// 查找该项的核对结果
                      final result = results.firstWhere(
                        (r) => r.contentId == content.id,
                        orElse: () => CheckResult(
                          contentId: content.id,
                          isCorrect: false,
                        ),
                      );

                      /// 检查是否已标记
                      final bool hasResult = results.any((r) => r.contentId == content.id);

                      /// 判断是否为古诗词类型
                      final bool isPoem = content.type == typeChinesePoem;

                      return _buildCheckItem(
                        context: context,
                        content: content,
                        hasResult: hasResult,
                        result: result,
                        isPoem: isPoem,
                        appState: appState,
                      );
                    },
                  ),
                ),

                /// 底部提交按钮区域
                _buildSubmitButton(context, appState),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 构建单个核对项卡片
  /// 左侧显示内容文字，右侧显示"对"/"错"操作按钮
  Widget _buildCheckItem({
    required BuildContext context,
    required Content content,
    required bool hasResult,
    required CheckResult result,
    required bool isPoem,
    required AppState appState,
  }) {
    /// 获取该项的缩放动画状态
    final bool isScaling = _scalingItems[content.id] ?? false;

    return AnimatedScale(
      /// 缩放动画：点击时缩小到0.95倍
      scale: isScaling ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        /// 已标记的项变灰背景
        color: hasResult ? Colors.grey[100] : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              /// 左侧内容文字区域
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// 内容大字（22sp加粗）
                    Text(
                      content.content,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: hasResult ? Colors.grey : const Color(0xFF212121),
                      ),
                    ),

                    /// 提示文字（16sp灰色）
                    if (content.hint != null && content.hint!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          content.hint!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),

                    /// 已标记结果显示
                    if (hasResult)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Text(
                              result.isCorrect ? '✓ 正确' : '✗ 错误',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: result.isCorrect ? Colors.green : Colors.red,
                              ),
                            ),
                            /// 显示错字信息
                            if (!result.isCorrect && result.wrongChar != null)
                              Text(
                                '（写成了：${result.wrongChar}）',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.red[300],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              /// 右侧操作按钮区域
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// "对"按钮 - 绿色背景，白色对勾图标
                  GestureDetector(
                    onTap: (hasResult && result.isCorrect)
                        ? null /// 已标记正确则不可点击
                        : () => _markCorrect(content.id, appState),
                    child: Container(
                      width: 80,
                      height: 56,
                      decoration: BoxDecoration(
                        color: (hasResult && result.isCorrect)
                            ? Colors.green.withOpacity(0.5)
                            : Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  /// "错"按钮 - 红色背景，白色叉号图标
                  GestureDetector(
                    onTap: (hasResult && !result.isCorrect)
                        ? null /// 已标记错误则不可点击
                        : () => _markWrong(content.id, appState),
                    child: Container(
                      width: 80,
                      height: 56,
                      decoration: BoxDecoration(
                        color: (hasResult && !result.isCorrect)
                            ? Colors.red.withOpacity(0.5)
                            : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  /// 古诗词类型额外显示"逐字核对"蓝色按钮
                  if (isPoem) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        /// 导航到逐字核对页面
                        Navigator.pushNamed(
                          context,
                          '/poemCheck',
                          arguments: content,
                        );
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.text_fields,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 标记该项为正确
  /// 播放缩放动画后更新状态
  Future<void> _markCorrect(String contentId, AppState appState) async {
    /// 开始缩放动画
    setState(() {
      _scalingItems[contentId] = true;
    });

    /// 等待动画播放
    await Future.delayed(const Duration(milliseconds: 150));

    /// 更新核对结果
    await appState.markCorrect(contentId);

    /// 恢复缩放动画
    setState(() {
      _scalingItems[contentId] = false;
    });
  }

  /// 标记该项为错误
  /// 弹出底部面板询问错字信息
  Future<void> _markWrong(String contentId, AppState appState) async {
    _wrongCharController.clear();

    /// 弹出错字输入对话框
    final String? wrongChar = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '这个字写错了',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '实际写成了什么字？',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            /// 错字输入框（单字限制）
            TextField(
              controller: _wrongCharController,
              autofocus: true,
              maxLength: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24),
              decoration: const InputDecoration(
                hintText: '输入错字',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            /// "不记得了"选项
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text(
                '不记得了',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, _wrongCharController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              '确认',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    /// 用户确认后才更新状态
    if (wrongChar != null) {
      /// 开始缩放动画
      setState(() {
        _scalingItems[contentId] = true;
      });

      await Future.delayed(const Duration(milliseconds: 150));

      /// 空字符串表示"不记得了"，不记录具体错字
      await appState.markWrong(
        contentId,
        wrongChar: wrongChar.isEmpty ? null : wrongChar,
      );

      /// 恢复缩放动画
      setState(() {
        _scalingItems[contentId] = false;
      });
    }
  }

  /// 构建底部提交按钮
  /// 蓝色大按钮，占据全屏宽度，64dp高
  Widget _buildSubmitButton(BuildContext context, AppState appState) {
    return GestureDetector(
      onTap: () async {
        /// 提交核对结果
        await appState.submitCheckResults();
        if (context.mounted) {
          /// 导航到结果页面
          Navigator.pushReplacementNamed(context, '/result');
        }
      },
      child: Container(
        width: double.infinity,
        height: 64,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            '提交',
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
}
