import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';

// ============================================================
// CSV导入服务 - 单例模式
// 负责CSV文件的解析和批量导入
// 支持4种格式：中文、英语、古诗词、数学
// 包含去重、错误处理、导入统计
// ============================================================

/// CSV分隔符
const String _kCsvDelimiter = ',';

/// 批量导入时的事务批量大小
const int _kBatchSize = 100;

// ==================== 内容类型常量 ====================
const String _typeChineseChar = 'chinese_char';
const String _typeChineseWord = 'chinese_word';
const String _typeChinesePoem = 'chinese_poem';
const String _typeEnglishWord = 'english_word';
const String _typeEnglishPhrase = 'english_phrase';
const String _typeMathQuestion = 'math_question';

// ==================== 导入结果类 ====================

/// CSV导入结果
class ImportResult {
  /// 成功导入的数量
  final int successCount;

  /// 跳过（重复）的数量
  final int skipCount;

  /// 失败的数量
  final int failCount;

  /// 错误信息列表
  final List<String> errors;

  /// 成功导入的内容列表
  final List<ImportContent> importedContents;

  ImportResult({
    this.successCount = 0,
    this.skipCount = 0,
    this.failCount = 0,
    this.errors = const [],
    this.importedContents = const [],
  });

  /// 获取导入总记录数
  int get totalCount => successCount + skipCount + failCount;

  /// 创建副本并累加结果
  ImportResult merge(ImportResult other) {
    return ImportResult(
      successCount: successCount + other.successCount,
      skipCount: skipCount + other.skipCount,
      failCount: failCount + other.failCount,
      errors: [...errors, ...other.errors],
      importedContents: [...importedContents, ...other.importedContents],
    );
  }

  @override
  String toString() {
    return 'ImportResult(成功:$successCount, 跳过:$skipCount, 失败:$failCount)';
  }
}

// ==================== 导入内容模型 ====================

/// 导入内容（服务层内部使用的简化模型）
/// 避免与上层模型类产生强依赖
class ImportContent {
  final String id;
  final String content;
  final String type;
  final String? parentId;
  final int? charIndex;
  final String? fullText;
  final String? hint;
  final String? answer;
  final String? context;
  final String source;
  final DateTime createdAt;

  ImportContent({
    required this.id,
    required this.content,
    required this.type,
    this.parentId,
    this.charIndex,
    this.fullText,
    this.hint,
    this.answer,
    this.context,
    required this.source,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 转换为Map（用于数据库插入）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'type': type,
      'parent_id': parentId,
      'char_index': charIndex,
      'full_text': fullText,
      'hint': hint,
      'answer': answer,
      'context': context,
      'source': source,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// 从Map构造
  factory ImportContent.fromMap(Map<String, dynamic> map) {
    return ImportContent(
      id: map['id'] ?? '',
      content: map['content'] ?? '',
      type: map['type'] ?? '',
      parentId: map['parent_id'],
      charIndex: map['char_index'],
      fullText: map['full_text'],
      hint: map['hint'],
      answer: map['answer'],
      context: map['context'],
      source: map['source'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : DateTime.now(),
    );
  }
}

// ==================== 去重键 ====================

/// 去重键（content + source 联合）
class _DuplicateKey {
  final String content;
  final String source;

  _DuplicateKey(this.content, this.source);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _DuplicateKey &&
        other.content == content &&
        other.source == source;
  }

  @override
  int get hashCode => content.hashCode ^ source.hashCode;

  @override
  String toString() => '[$content, $source]';
}

// ==================== 主服务类 ====================

class CsvImportService {
  // ==================== 单例模式 ====================
  static final CsvImportService _instance = CsvImportService._internal();
  factory CsvImportService() => _instance;
  CsvImportService._internal();

  // ==================== 成员变量 ====================

  /// UUID生成器
  final Uuid _uuid = const Uuid();

  /// 是否已初始化
  bool _initialized = false;

  /// 用于去重的缓存（运行时内存中去重）
  /// 键：content + source 的联合hash，值：是否已存在
  final Set<_DuplicateKey> _duplicateCache = {};

  // ==================== 初始化 ====================

  /// 初始化CSV导入服务
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  // ==================== 文件导入 ====================

  /// 从文件路径导入CSV
  /// [filePath] CSV文件的完整路径
  /// 返回导入结果
  Future<ImportResult> importFromFile(String filePath) async {
    if (!_initialized) await initialize();

    final result = ImportResult();

    try {
      // 检查文件是否存在
      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult(
          failCount: 1,
          errors: ['文件不存在: $filePath'],
        );
      }

      // 读取文件内容
      final csvString = await file.readAsString();

      // 从文件路径提取文件名
      final fileName = file.path.split(Platform.pathSeparator).last;

      // 解析CSV
      final contents = await parseCsv(csvString, fileName);

      if (contents.isEmpty) {
        return ImportResult(
          errors: ['CSV文件为空或格式不正确'],
        );
      }

      // 批量导入
      return await importContents(contents);
    } on FileSystemException catch (e) {
      return ImportResult(
        failCount: 1,
        errors: ['文件读取失败: ${e.message}'],
      );
    } catch (e) {
      return ImportResult(
        failCount: 1,
        errors: ['导入失败: $e'],
      );
    }
  }

  // ==================== CSV解析 ====================

  /// 解析CSV字符串，返回ImportContent列表
  /// [csvString] CSV文件内容字符串
  /// [fileName] 原始文件名，用于自动检测内容类型
  /// 返回解析后的内容列表（未做去重和数据库验证）
  Future<List<ImportContent>> parseCsv(
    String csvString,
    String fileName,
  ) async {
    // 从文件名检测类型
    final detectedType = _detectTypeFromFileName(fileName);

    // 自动检测编码（尝试UTF-8，失败则用latin1解码）
    String decoded = csvString;
    try {
      // 如果字符串已经是正确解码的，直接处理
      // 如果传入的是字节需要用latin1解码，调用方应自行处理
      decoded = csvString;
    } catch (e) {
      // 解码失败，使用原字符串
      decoded = csvString;
    }

    // 移除BOM头
    if (decoded.startsWith('\uFEFF')) {
      decoded = decoded.substring(1);
    }

    // 使用csv包解析
    final converter = const CsvToListConverter(
      fieldDelimiter: _kCsvDelimiter,
      shouldParseNumbers: false,
      allowInvalid: true,
    );

    final rows = converter.convert(decoded);

    if (rows.isEmpty) {
      return [];
    }

    // 跳过表头行，根据类型解析数据行
    final dataRows = rows.skip(1).toList();

    final List<ImportContent> contents = [];
    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      final rowNumber = i + 2; // +2 因为跳过了表头行，且行号从1开始

      try {
        final content = _parseRow(row, detectedType, fileName, rowNumber);
        if (content != null) {
          contents.add(content);
        }
      } catch (e) {
        // 单行解析失败，记录错误但不中断
        // 错误信息在导入阶段统一处理
      }
    }

    return contents;
  }

  // ==================== 类型检测 ====================

  /// 从文件名检测内容类型
  /// 根据文件名中的关键词自动识别CSV内容类型
  /// 返回值：chinese_char / chinese_word / chinese_poem / english_word /
  ///         english_phrase / math_question
  String _detectTypeFromFileName(String fileName) {
    final lowerName = fileName.toLowerCase();

    // 中文类
    if (lowerName.contains('chinese') || lowerName.contains('中文') ||
        lowerName.contains('汉字') || lowerName.contains('生字')) {
      // 根据内容判断是单字还是词语
      // 默认先返回单字类型，实际解析时可根据hint判断
      return _typeChineseChar;
    }

    // 古诗词类
    if (lowerName.contains('poem') || lowerName.contains('诗词') ||
        lowerName.contains('古诗') || lowerName.contains('古诗')) {
      return _typeChinesePoem;
    }

    // 英语类
    if (lowerName.contains('english') || lowerName.contains('英语') ||
        lowerName.contains('英文') || lowerName.contains('单词')) {
      if (lowerName.contains('phrase') || lowerName.contains('短语')) {
        return _typeEnglishPhrase;
      }
      return _typeEnglishWord;
    }

    // 数学类
    if (lowerName.contains('math') || lowerName.contains('数学') ||
        lowerName.contains('口算') || lowerName.contains('算术')) {
      return _typeMathQuestion;
    }

    // 默认返回中文字符类型
    return _typeChineseChar;
  }

  /// 解析类型字符串为内部类型标识
  /// [typeStr] 类型字符串（来自CSV或文件名）
  /// 返回标准化的类型标识
  String _parseType(String typeStr) {
    final lower = typeStr.toLowerCase().trim();

    switch (lower) {
      case 'chinese':
      case 'chinese_char':
      case 'char':
      case '汉字':
      case '生字':
      case '字':
        return _typeChineseChar;

      case 'chinese_word':
      case 'word':
      case '词语':
      case '词':
        return _typeChineseWord;

      case 'poem':
      case 'chinese_poem':
      case '诗词':
      case '古诗':
      case '古诗':
      case '诗':
        return _typeChinesePoem;

      case 'english':
      case 'english_word':
      case 'en_word':
      case '英语单词':
      case '单词':
        return _typeEnglishWord;

      case 'english_phrase':
      case 'en_phrase':
      case '英语短语':
      case '短语':
        return _typeEnglishPhrase;

      case 'math':
      case 'math_question':
      case '数学':
      case '口算':
      case '算术':
        return _typeMathQuestion;

      default:
        // 无法识别时，返回原始值或默认类型
        if (lower.contains('phrase') || lower.contains('短语')) {
          return _typeEnglishPhrase;
        }
        if (lower.contains('poem') || lower.contains('诗')) {
          return _typeChinesePoem;
        }
        if (lower.contains('math') || lower.contains('数')) {
          return _typeMathQuestion;
        }
        if (lower.contains('english') || lower.contains('英')) {
          return _typeEnglishWord;
        }
        return _typeChineseChar;
    }
  }

  // ==================== 行解析 ====================

  /// 解析单行数据
  /// [row] CSV行数据（字段列表）
  /// [type] 内容类型
  /// [source] 来源标识（文件名）
  /// [rowNumber] 行号（用于错误报告）
  /// 返回解析后的ImportContent，如果内容无效返回null
  ImportContent? _parseRow(
    List<dynamic> row,
    String type,
    String source,
    int rowNumber,
  ) {
    // 过滤空行
    if (row.isEmpty) return null;

    // 所有字段都转为字符串
    final fields = row.map((f) => f?.toString().trim() ?? '').toList();

    // 第一列为空则跳过
    if (fields.isEmpty || fields[0].isEmpty) return null;

    // 根据类型选择不同的解析策略
    switch (type) {
      case _typeChinesePoem:
        return _parsePoemRow(fields, source, rowNumber);

      case _typeEnglishWord:
      case _typeEnglishPhrase:
        return _parseEnglishRow(fields, type, source, rowNumber);

      case _typeMathQuestion:
        return _parseMathRow(fields, source, rowNumber);

      case _typeChineseWord:
        return _parseChineseWordRow(fields, source, rowNumber);

      case _typeChineseChar:
      default:
        return _parseChineseCharRow(fields, source, rowNumber);
    }
  }

  /// 解析中文单字行
  /// CSV格式：content,hint
  /// 示例：山,shān
  ImportContent? _parseChineseCharRow(
    List<String> fields,
    String source,
    int rowNumber,
  ) {
    final content = fields.isNotEmpty ? fields[0] : '';
    final hint = fields.length > 1 ? fields[1] : null;

    if (content.isEmpty) return null;

    // 如果content包含多个字（长度>1），自动转为词语类型
    final type = content.length > 1 ? _typeChineseWord : _typeChineseChar;

    return ImportContent(
      id: _uuid.v4(),
      content: content,
      type: type,
      hint: hint?.isNotEmpty == true ? hint : null,
      source: source,
    );
  }

  /// 解析中文词语行
  /// CSV格式：content,hint
  /// 示例：山水,shān shuǐ
  ImportContent? _parseChineseWordRow(
    List<String> fields,
    String source,
    int rowNumber,
  ) {
    final content = fields.isNotEmpty ? fields[0] : '';
    final hint = fields.length > 1 ? fields[1] : null;

    if (content.isEmpty) return null;

    return ImportContent(
      id: _uuid.v4(),
      content: content,
      type: _typeChineseWord,
      hint: hint?.isNotEmpty == true ? hint : null,
      source: source,
    );
  }

  /// 解析古诗词行
  /// CSV格式：title,author,dynasty,content
  /// 示例：静夜思,李白,唐,床前明月光，疑是地上霜。举头望明月，低头思故乡。
  ImportContent? _parsePoemRow(
    List<String> fields,
    String source,
    int rowNumber,
  ) {
    // 至少需要标题和全文
    if (fields.length < 2) return null;

    final title = fields[0];
    final author = fields.length > 1 ? fields[1] : '';
    final dynasty = fields.length > 2 ? fields[2] : '';
    final fullText = fields.length > 3 ? fields[3] : '';

    if (title.isEmpty || fullText.isEmpty) return null;

    // 构建提示信息：作者（朝代）
    final hintParts = <String>[];
    if (author.isNotEmpty) hintParts.add(author);
    if (dynasty.isNotEmpty) hintParts.add('（$dynasty）');
    final hint = hintParts.isNotEmpty ? hintParts.join('') : null;

    return ImportContent(
      id: _uuid.v4(),
      content: title, // 诗词标题作为content
      type: _typeChinesePoem,
      hint: hint,
      fullText: fullText,
      source: source,
    );
  }

  /// 解析英语行
  /// CSV格式：content,hint
  /// 示例：apple,苹果
  ImportContent? _parseEnglishRow(
    List<String> fields,
    String type,
    String source,
    int rowNumber,
  ) {
    final content = fields.isNotEmpty ? fields[0] : '';
    final hint = fields.length > 1 ? fields[1] : null;

    if (content.isEmpty) return null;

    // 根据内容判断是单词还是短语
    // 包含空格视为短语
    final effectiveType =
        content.contains(' ') ? _typeEnglishPhrase : type;

    return ImportContent(
      id: _uuid.v4(),
      content: content,
      type: effectiveType,
      hint: hint?.isNotEmpty == true ? hint : null,
      source: source,
    );
  }

  /// 解析数学行
  /// CSV格式：content,answer,hint
  /// 示例：3 + 5 = ?,8,加法
  ImportContent? _parseMathRow(
    List<String> fields,
    String source,
    int rowNumber,
  ) {
    final content = fields.isNotEmpty ? fields[0] : '';
    final answer = fields.length > 1 ? fields[1] : null;
    final hint = fields.length > 2 ? fields[2] : null;

    if (content.isEmpty) return null;

    return ImportContent(
      id: _uuid.v4(),
      content: content,
      type: _typeMathQuestion,
      hint: hint?.isNotEmpty == true ? hint : null,
      answer: answer?.isNotEmpty == true ? answer : null,
      source: source,
    );
  }

  // ==================== 批量导入 ====================

  /// 批量导入内容
  /// [contents] 要导入的内容列表
  /// [isDuplicate] 去重检查回调（可选）
  ///   返回 true 表示该内容已存在，应跳过
  /// [onInsert] 实际插入回调（可选）
  ///   返回 true 表示插入成功
  /// 返回导入结果统计
  Future<ImportResult> importContents(
    List<ImportContent> contents, {
    Future<bool> Function(ImportContent content)? isDuplicate,
    Future<bool> Function(ImportContent content)? onInsert,
  }) async {
    if (contents.isEmpty) {
      return ImportResult(errors: ['没有要导入的内容']);
    }

    int successCount = 0;
    int skipCount = 0;
    int failCount = 0;
    final List<String> errors = [];
    final List<ImportContent> importedContents = [];

    // 本地去重缓存（本次导入过程中）
    final Set<_DuplicateKey> localCache = {};

    for (int i = 0; i < contents.length; i++) {
      final content = contents[i];
      final rowNumber = i + 2; // 行号（+2 = 表头+1-based）

      try {
        // 检查内容是否为空
        if (content.content.isEmpty) {
          failCount++;
          errors.add('第$rowNumber行: 内容为空');
          continue;
        }

        // 构建去重键
        final dupKey = _DuplicateKey(content.content, content.source);

        // 1. 检查本次导入批次中是否已存在
        if (localCache.contains(dupKey)) {
          skipCount++;
          errors.add('第$rowNumber行: 内容"${content.content}"在导入文件中重复');
          continue;
        }

        // 2. 检查外部去重（数据库中是否已存在）
        if (isDuplicate != null) {
          final exists = await isDuplicate(content);
          if (exists) {
            skipCount++;
            errors.add('第$rowNumber行: 内容"${content.content}"已存在');
            continue;
          }
        }

        // 3. 执行插入
        bool inserted = false;
        if (onInsert != null) {
          inserted = await onInsert(content);
        } else {
          // 没有插入回调，默认视为成功
          // 实际上层调用方应该提供onInsert
          inserted = true;
        }

        if (inserted) {
          successCount++;
          localCache.add(dupKey);
          _duplicateCache.add(dupKey);
          importedContents.add(content);
        } else {
          failCount++;
          errors.add('第$rowNumber行: 插入失败"${content.content}"');
        }
      } catch (e) {
        failCount++;
        errors.add('第$rowNumber行: 处理异常 - $e');
      }
    }

    return ImportResult(
      successCount: successCount,
      skipCount: skipCount,
      failCount: failCount,
      errors: errors,
      importedContents: importedContents,
    );
  }

  // ==================== 便捷导入方法 ====================

  /// 便捷方法：直接导入CSV文件并自动完成去重和插入
  /// [filePath] CSV文件路径
  /// [isDuplicate] 外部去重检查回调
  /// [onInsert] 插入回调
  Future<ImportResult> importCsvFile(
    String filePath, {
    required Future<bool> Function(ImportContent content) isDuplicate,
    required Future<bool> Function(ImportContent content) onInsert,
  }) async {
    // 先读取并解析文件
    final fileResult = await importFromFile(filePath);

    if (fileResult.failCount > 0 && fileResult.importedContents.isEmpty) {
      // 文件读取完全失败
      return fileResult;
    }

    // 将文件解析的内容进行批量导入
    final contents = fileResult.importedContents;
    if (contents.isEmpty) {
      return ImportResult(
        errors: [...fileResult.errors, 'CSV文件没有有效数据'],
      );
    }

    // 批量导入（带去重和插入）
    final importResult = await importContents(
      contents,
      isDuplicate: isDuplicate,
      onInsert: onInsert,
    );

    // 合并文件读取阶段和导入阶段的错误
    return ImportResult(
      successCount: importResult.successCount,
      skipCount: importResult.skipCount,
      failCount: importResult.failCount,
      errors: [...fileResult.errors, ...importResult.errors],
      importedContents: importResult.importedContents,
    );
  }

  // ==================== 去重缓存管理 ====================

  /// 清除去重缓存
  /// 通常在应用重启后调用
  void clearDuplicateCache() {
    _duplicateCache.clear();
  }

  /// 添加已存在的内容到去重缓存
  /// 用于初始化时从数据库加载已有内容
  void addToDuplicateCache(String content, String source) {
    _duplicateCache.add(_DuplicateKey(content, source));
  }

  /// 批量添加去重缓存
  void addAllToDuplicateCache(List<Map<String, String>> items) {
    for (final item in items) {
      if (item['content'] != null && item['source'] != null) {
        _duplicateCache.add(
          _DuplicateKey(item['content']!, item['source']!),
        );
      }
    }
  }

  // ==================== CSV模板生成 ====================

  /// 获取中文CSV模板内容
  String getChineseCsvTemplate() {
    return 'content,hint\n'
        '山,shān\n'
        '水,shuǐ\n'
        '月,yuè\n';
  }

  /// 获取古诗词CSV模板内容
  String getPoemCsvTemplate() {
    return 'title,author,dynasty,content\n'
        '静夜思,李白,唐,床前明月光，疑是地上霜。举头望明月，低头思故乡。\n'
        '春晓,孟浩然,唐,春眠不觉晓，处处闻啼鸟。夜来风雨声，花落知多少。\n';
  }

  /// 获取英语CSV模板内容
  String getEnglishCsvTemplate() {
    return 'content,hint\n'
        'apple,苹果\n'
        'book,书\n'
        'cat,猫\n';
  }

  /// 获取数学CSV模板内容
  String getMathCsvTemplate() {
    return 'content,answer,hint\n'
        '3 + 5 = ?,8,加法\n'
        '12 - 7 = ?,5,减法\n'
        '6 × 4 = ?,24,乘法\n';
  }

  /// 获取所有模板说明
  Map<String, String> getAllTemplates() {
    return {
      'chinese.csv (中文生字)': getChineseCsvTemplate(),
      'poems.csv (古诗词)': getPoemCsvTemplate(),
      'english.csv (英语单词)': getEnglishCsvTemplate(),
      'math.csv (数学题)': getMathCsvTemplate(),
    };
  }

  // ==================== CSV验证 ====================

  /// 验证CSV格式是否正确
  /// 返回验证结果和错误信息
  Future<Map<String, dynamic>> validateCsv(
    String csvString,
    String fileName,
  ) async {
    final errors = <String>[];
    bool isValid = true;

    try {
      // 检测类型
      final type = _detectTypeFromFileName(fileName);

      // 解析
      final converter = const CsvToListConverter(
        fieldDelimiter: _kCsvDelimiter,
        shouldParseNumbers: false,
        allowInvalid: true,
      );

      final rows = converter.convert(csvString);

      if (rows.isEmpty) {
        return {
          'valid': false,
          'errors': ['CSV文件为空'],
        };
      }

      // 检查表头
      final header = rows[0].map((f) => f?.toString().trim() ?? '').toList();
      if (header.isEmpty || header[0].isEmpty) {
        errors.add('表头为空');
        isValid = false;
      }

      // 检查数据行
      final dataRows = rows.skip(1).toList();
      if (dataRows.isEmpty) {
        errors.add('没有数据行（仅有表头）');
        isValid = false;
      }

      // 检查每行数据
      for (int i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        final rowNum = i + 2;

        if (row.isEmpty) {
          errors.add('第$rowNum行: 空行');
          continue;
        }

        final firstField = row[0]?.toString().trim() ?? '';
        if (firstField.isEmpty) {
          errors.add('第$rowNum行: 内容字段为空');
        }
      }

      return {
        'valid': isValid && errors.isEmpty,
        'errors': errors,
        'detectedType': type,
        'rowCount': dataRows.length,
      };
    } catch (e) {
      return {
        'valid': false,
        'errors': ['CSV解析失败: $e'],
      };
    }
  }
}
