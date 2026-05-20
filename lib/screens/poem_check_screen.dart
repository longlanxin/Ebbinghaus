import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../utils/constants.dart';

/// 古诗词逐字核对页
/// 全诗大字显示，每个字可独立标记正确/错误
/// 三态切换：灰色(未标记) -> 绿色(正确) -> 红色(错误) -> 灰色(恢复)
/// 适用于古诗词的精细化核对场景
class PoemCheckScreen extends StatefulWidget {
  const PoemCheckScreen({Key? key}) : super(key: key);

  @override
  State<PoemCheckScreen> createState() => _PoemCheckScreenState();
}

class _PoemCheckScreenState extends State<PoemCheckScreen> {
  /// 每个字的状态：0=未标记(灰色), 1=正确(绿色), 2=错误(红色)
  late List<int> _charStatus;

  /// 错字记录（位置索引 -> 写成的错字）
  final Map<int, String> _wrongChars = {};

  /// 错字输入控制器
  final TextEditingController _wrongCharController = TextEditingController();

  /// 获取当前古诗词内容（可能为null，需要检查）
  Content? _poemContent;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    /// 从路由参数获取古诗词内容
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Content && !_initialized) {
      _poemContent = args;
      /// 初始化每个字的状态为未标记
      final fullText = _poemContent!.fullText ?? _poemContent!.content;
      _charStatus = List.filled(fullText.length, 0);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _wrongCharController.dispose();
    super.dispose();
  }

  /// 处理字点击事件
  /// 三态循环切换：0(灰) -> 1(绿) -> 2(红) -> 0(灰)
  Future<void> _onCharTap(int index) async {
    setState(() {
      /// 循环切换状态
      _charStatus[index] = (_charStatus[index] + 1) % 3;
    });

    /// 如果标记为错误(2)，弹出输入框记录错字
    if (_charStatus[index] == 2) {
      if (_poemContent == null) return;
      final fullText = _poemContent!.fullText ?? _poemContent!.content;
      _wrongCharController.clear();

      final wrongChar = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            '记录错字',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '原字：${fullText[index]}',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _wrongCharController,
                autofocus: true,
                maxLength: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24),
                decoration: const InputDecoration(
                  hintText: '这个字写成了什么？',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              onPressed: () => Navigator.pop(context, _wrongCharController.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                '确认',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (wrongChar != null && wrongChar.isNotEmpty) {
        setState(() {
          _wrongChars[index] = wrongChar;
        });
      }
    } else if (_charStatus[index] == 0) {
      /// 恢复为未标记状态时，清除错字记录
      setState(() {
        _wrongChars.remove(index);
      });
    }
  }

  /// 一键标记所有字为正确（绿色）
  /// 仅标记尚未标记为错误的字
  void _markAllCorrect() {
    setState(() {
      for (int i = 0; i < _charStatus.length; i++) {
        /// 只标记尚未标记为错误的字
        if (_charStatus[i] != 2) {
          _charStatus[i] = 1;
        }
      }
    });
  }

  /// 提交逐字核对结果
  /// 检查是否有未标记的字，提示用户确认
  Future<void> _submit() async {
    /// 安全检查
    if (_poemContent == null) return;
    final fullText = _poemContent!.fullText ?? _poemContent!.content;

    /// 统计未标记的字数
    final unmarkedCount = _charStatus.where((s) => s == 0).length;

    if (unmarkedCount > 0) {
      /// 有未标记的字，弹出提示
      final bool confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text(
                '还有未核对的字',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                '还有$unmarkedCount个字未核对，确定提交吗？',
                style: const TextStyle(fontSize: 18),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    '继续核对',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text(
                    '确认提交',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirm) return;
    }

    /// 有错字则整体标记为错误
    final bool hasError = _charStatus.any((s) => s == 2);

    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);

    if (hasError) {
      /// 记录错字信息
      final wrongInfo = _wrongChars.entries.map((e) {
        return '位置${e.key}: ${fullText[e.key]} -> ${e.value}';
      }).join(', ');
      await appState.markWrong(_poemContent!.id, wrongChar: wrongInfo);
    } else {
      await appState.markCorrect(_poemContent!.id);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    /// 未初始化时显示加载中
    if (!_initialized || _poemContent == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF8E1),
        appBar: AppBar(
          title: const Text('逐字核对', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
        ),
        body: const Center(
          child: Text('加载中...', style: TextStyle(fontSize: 20, color: Color(0xFF757575))),
        ),
      );
    }

    final fullText = _poemContent!.fullText ?? _poemContent!.content;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        title: const Text(
          '逐字核对',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => Navigator.pop(context),
          tooltip: '返回',
        ),
        actions: [
          /// 右上角"全对"按钮，一键标记所有字正确
          TextButton(
            onPressed: _markAllCorrect,
            child: const Text(
              '全对',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            /// 诗词标题区域
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _poemContent!.content,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF757575),
                ),
              ),
            ),

            /// 诗词作者/朝代提示
            if (_poemContent!.hint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _poemContent!.hint!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF757575),
                  ),
                ),
              ),

            /// 逐字显示和点击区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: List.generate(fullText.length, (index) {
                    final char = fullText[index];
                    final status = _charStatus[index];

                    /// 标点符号不参与核对，直接显示
                    if (_isPunctuation(char)) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          char,
                          style: const TextStyle(
                            fontSize: 22,
                            color: Color(0xFF757575),
                          ),
                        ),
                      );
                    }

                    /// 可点击的字单元
                    return GestureDetector(
                      onTap: () => _onCharTap(index),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          /// 顶部小圆点状态指示器
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: status == 0
                                  ? Colors.grey[400]
                                  : status == 1
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          ),

                          /// 字单元容器（60x60）
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: status == 0
                                  ? Colors.grey[200]
                                  : status == 1
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: status == 0
                                    ? Colors.grey[300]!
                                    : status == 1
                                        ? Colors.green
                                        : Colors.red,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                char,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: status == 0
                                      ? const Color(0xFF212121)
                                      : status == 1
                                          ? Colors.green
                                          : Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),

            /// 底部操作按钮区域
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  /// 判断字符是否为标点符号
  /// 标点符号不参与逐字核对
  bool _isPunctuation(String char) {
    const punctuation = '，。！？、；：""''（）《》【】…—·\n\r\t ';
    return punctuation.contains(char);
  }

  /// 构建底部操作按钮
  /// 包含：返回、一键全对、提交
  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          /// 返回按钮（灰色）
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 56,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    '返回',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF212121),
                    ),
                  ),
                ),
              ),
            ),
          ),

          /// 一键全对按钮（绿色）
          Expanded(
            child: GestureDetector(
              onTap: _markAllCorrect,
              child: Container(
                height: 56,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    '这些我都写对了',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          /// 提交按钮（蓝色）
          Expanded(
            child: GestureDetector(
              onTap: _submit,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    '提交',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
