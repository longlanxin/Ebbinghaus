// lib/screens/import_screen.dart
// CSV导入页面
// 家长通过此页面选择CSV文件并导入学习内容
// 支持语文、英语、古诗词、数学四种格式的CSV文件

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/services.dart';
import '../utils/constants.dart';

// ============================================================
// ImportScreen - CSV导入页面
// ============================================================

/// CSV导入页面
///
/// 功能流程：
/// 1. 显示CSV格式说明
/// 2. 点击"选择CSV文件"按钮
/// 3. 使用file_picker选择.csv文件
/// 4. 调用CsvImportService.importFromFile解析并导入
/// 5. 显示导入结果（成功/跳过/失败）
/// 6. 如有失败，展示失败详情列表
///
/// 支持的CSV格式：
/// - 中文生字：content,hint（如：山,shān）
/// - 古诗词：title,author,dynasty,content
/// - 英语单词：content,hint（如：apple,苹果）
/// - 数学题：content,answer,hint
class ImportScreen extends StatefulWidget {
  /// 路由名称
  static const String routeName = '/import';

  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  // CSV导入服务实例
  final CsvImportService _csvService = CsvImportService();

  // 导入结果
  ImportResult? _importResult;

  // 是否正在导入中
  bool _isImporting = false;

  // 是否展开CSV格式说明
  bool _isTemplateExpanded = false;

  // 导入的CSV模板说明
  late final Map<String, String> _templates;

  @override
  void initState() {
    super.initState();
    // 预加载CSV模板说明
    _templates = _csvService.getAllTemplates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 护眼背景色
      backgroundColor: const Color(kBackgroundColor),
      appBar: AppBar(
        title: const Text(
          '导入学习内容',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(kPrimaryColor),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ========== 顶部说明卡片 ==========
            _buildInfoCard(),
            const SizedBox(height: 20),

            // ========== 选择文件按钮 ==========
            _buildSelectFileButton(),
            const SizedBox(height: 20),

            // ========== 加载指示器 ==========
            if (_isImporting) _buildLoadingIndicator(),

            // ========== 导入结果区域 ==========
            if (_importResult != null && !_isImporting) _buildResultArea(),

            const SizedBox(height: 20),

            // ========== CSV格式说明（可展开） ==========
            _buildTemplateExpansionCard(),
          ],
        ),
      ),
    );
  }

  /// 构建顶部说明卡片
  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue[700],
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  '使用说明',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '请先从手机中选择CSV文件。支持语文、英语、古诗词、数学四种格式。',
              style: TextStyle(
                fontSize: 18,
                color: Color(kTextPrimaryColor),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建选择文件按钮
  Widget _buildSelectFileButton() {
    return ElevatedButton.icon(
      onPressed: _isImporting ? null : _pickAndImportFile,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(kPrimaryColor),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 64),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
      ),
      icon: const Icon(Icons.folder_open, size: 28),
      label: const Text(
        '选择CSV文件',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 构建加载指示器
  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        children: [
          SizedBox(height: 20),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(kPrimaryColor)),
            strokeWidth: 4,
          ),
          SizedBox(height: 16),
          Text(
            '正在导入，请稍候...',
            style: TextStyle(
              fontSize: 18,
              color: Color(kTextSecondaryColor),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建导入结果区域
  Widget _buildResultArea() {
    final result = _importResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 结果标题
        const Text(
          '导入结果',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // 统计卡片
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 成功数 - 绿色
                _buildResultRow(
                  Icons.check_circle,
                  Colors.green,
                  '成功导入',
                  '${result.successCount} 条',
                ),
                const Divider(height: 24),
                // 跳过数 - 橙色
                _buildResultRow(
                  Icons.skip_next,
                  Colors.orange,
                  '跳过（重复）',
                  '${result.skipCount} 条',
                ),
                const Divider(height: 24),
                // 失败数 - 红色
                _buildResultRow(
                  Icons.error,
                  Colors.red,
                  '失败',
                  '${result.failCount} 条',
                ),
              ],
            ),
          ),
        ),

        // 失败详情
        if (result.failCount > 0) ...[
          const SizedBox(height: 16),
          const Text(
            '失败详情',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          _buildErrorList(result.errors),
        ],
      ],
    );
  }

  /// 构建结果统计行
  Widget _buildResultRow(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              color: Color(kTextPrimaryColor),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 构建失败详情列表
  Widget _buildErrorList(List<String> errors) {
    // 只显示失败的错误信息
    final failErrors = errors.where((e) => e.contains('失败') || e.contains('错误') || e.contains('空')).toList();
    if (failErrors.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: Text(
            '没有详细错误信息',
            style: TextStyle(fontSize: 16, color: Color(kTextSecondaryColor)),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: failErrors.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.error_outline, color: Colors.red, size: 22),
            title: Text(
              failErrors[index],
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
            ),
            dense: true,
          );
        },
      ),
    );
  }

  /// 构建CSV格式说明可展开卡片
  Widget _buildTemplateExpansionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: const Row(
          children: [
            Icon(Icons.description, color: Color(kPrimaryColor)),
            SizedBox(width: 8),
            Text(
              'CSV格式说明',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        initiallyExpanded: _isTemplateExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isTemplateExpanded = expanded;
          });
        },
        children: _templates.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(kPrimaryColor),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 选择并导入CSV文件
  ///
  /// 使用file_picker选择.csv文件，然后调用CsvImportService导入
  Future<void> _pickAndImportFile() async {
    setState(() {
      _isImporting = true;
      _importResult = null;
    });

    try {
      // 使用file_picker选择文件
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // 用户取消选择
        setState(() {
          _isImporting = false;
        });
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null || filePath.isEmpty) {
        setState(() {
          _isImporting = false;
          _importResult = ImportResult(
            failCount: 1,
            errors: ['无法获取文件路径'],
          );
        });
        return;
      }

      // 调用CSV导入服务
      final importResult = await _csvService.importFromFile(filePath);

      setState(() {
        _importResult = importResult;
        _isImporting = false;
      });

      // 显示导入完成的提示
      if (mounted) {
        final snackBar = SnackBar(
          content: Text(
            '导入完成：成功 ${importResult.successCount} 条，跳过 ${importResult.skipCount} 条，失败 ${importResult.failCount} 条',
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: importResult.failCount == 0
              ? const Color(kPrimaryColor)
              : Colors.orange,
          duration: const Duration(seconds: 3),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _importResult = ImportResult(
          failCount: 1,
          errors: ['导入异常: $e'],
        );
      });
    }
  }
}
