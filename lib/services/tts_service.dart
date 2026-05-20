import 'dart:async';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// TTS 语音播报服务 - 单例模式
// 负责所有语音播报功能，包括内容智能播报、语速控制
// ============================================================

/// 内容类型常量（与模型层保持一致）
const String _typeChineseChar = 'chinese_char';
const String _typeChineseWord = 'chinese_word';
const String _typeChinesePoem = 'chinese_poem';
const String _typeEnglishWord = 'english_word';
const String _typeEnglishPhrase = 'english_phrase';
const String _typeMathQuestion = 'math_question';

/// 默认语速
const double _kDefaultRate = 0.5;

/// 语速持久化存储的Key
const String _kTtsRateKey = 'tts_rate';

/// 最小/最大语速限制
const double _kMinRate = 0.1;
const double _kMaxRate = 1.0;

/// 古诗词逐句播报的停顿间隔（毫秒）
const int _kPoemLineDelayMs = 1500;

/// 简化的内容模型，用于服务层内部
/// 避免与上层模型产生强依赖
class _TtsContent {
  final String content;
  final String type;
  final String? hint;
  final String? fullText;
  final String? answer;

  _TtsContent({
    required this.content,
    required this.type,
    this.hint,
    this.fullText,
    this.answer,
  });

  /// 从外部传入的Map构造
  factory _TtsContent.fromMap(Map<String, dynamic> map) {
    return _TtsContent(
      content: map['content'] ?? '',
      type: map['type'] ?? '',
      hint: map['hint'],
      fullText: map['fullText'],
      answer: map['answer'],
    );
  }
}

class TTSService {
  // ==================== 单例模式 ====================
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  // ==================== 成员变量 ====================
  final FlutterTts _flutterTts = FlutterTts();

  /// 是否已初始化
  bool _initialized = false;

  /// TTS是否可用
  bool _isAvailable = false;

  /// 当前语速（0.1 - 1.0）
  double _currentRate = _kDefaultRate;

  /// 是否正在播报中
  bool _isSpeaking = false;

  /// 中文语音包是否就绪
  bool _chineseVoiceReady = false;

  /// 播报完成的Completer
  Completer<void>? _speakCompleter;

  /// 获取当前是否正在播报
  bool get isSpeaking => _isSpeaking;

  // ==================== 初始化 ====================

  /// 初始化TTS服务
  /// - 设置默认语言为中文
  /// - 检测系统TTS引擎
  /// - 检查中文语音包可用性
  /// - 从持久化存储读取语速设置
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 设置完成回调
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _speakCompleter?.complete();
      });

      // 设置错误回调
      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        _speakCompleter?.completeError('TTS播报错误: $msg');
      });

      // 获取可用语言列表
      final languages = await _flutterTts.getLanguages;
      _chineseVoiceReady = _checkChineseSupport(languages);

      // 获取可用TTS引擎
      final engines = await _flutterTts.getEngines;
      if (engines == null || engines.isEmpty) {
        _isAvailable = false;
        _initialized = true;
        return;
      }

      // 尝试设置为中文
      if (_chineseVoiceReady) {
        await _flutterTts.setLanguage('zh-CN');
      } else {
        // 回退：尝试其他中文变体
        await _flutterTts.setLanguage('zh-TW');
      }

      // 设置默认语速
      await _loadRateFromPrefs();
      await _flutterTts.setSpeechRate(_currentRate);

      // 设置音量（0-1）
      await _flutterTts.setVolume(1.0);

      // 设置音调
      await _flutterTts.setPitch(1.0);

      // 检查TTS是否真正可用
      _isAvailable = await _flutterTts.isLanguageAvailable('zh-CN') ?? false;

      _initialized = true;
    } catch (e) {
      _isAvailable = false;
      _initialized = true;
    }
  }

  /// 检查语音列表中是否支持中文
  bool _checkChineseSupport(dynamic languages) {
    if (languages == null || languages is! List) return false;
    return languages.any((lang) {
      final langStr = lang.toString().toLowerCase();
      return langStr.contains('zh') || langStr.contains('cmn');
    });
  }

  // ==================== 可用性检查 ====================

  /// 检查TTS是否可用
  /// 返回 true 表示系统已安装TTS引擎且中文语音就绪
  Future<bool> isAvailable() async {
    if (!_initialized) {
      await initialize();
    }
    return _isAvailable && _chineseVoiceReady;
  }

  /// 获取中文语音包状态
  bool get isChineseVoiceReady => _chineseVoiceReady;

  // ==================== 基础播报 ====================

  /// 播报文字
  /// [text] 要播报的文字
  /// [rate] 语速，范围 0.1 - 1.0，默认使用当前设置
  Future<void> speak(String text, {double? rate}) async {
    if (!_initialized) await initialize();
    if (!_isAvailable) {
      return;
    }

    try {
      // 停止当前播报
      await stop();

      // 如果指定了语速，临时应用
      if (rate != null && rate != _currentRate) {
        final clampedRate = rate.clamp(_kMinRate, _kMaxRate);
        await _flutterTts.setSpeechRate(clampedRate);
      }

      _isSpeaking = true;
      _speakCompleter = Completer<void>();

      await _flutterTts.speak(text);

      // 等待播报完成
      await _speakCompleter!.future;
    } catch (e) {
      _isSpeaking = false;
    } finally {
      // 恢复原始语速
      if (rate != null && rate != _currentRate) {
        await _flutterTts.setSpeechRate(_currentRate);
      }
    }
  }

  /// 停止播报
  Future<void> stop() async {
    try {
      _isSpeaking = false;
      await _flutterTts.stop();
      if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
        _speakCompleter!.complete();
      }
    } catch (e) {
      // 忽略停止时的错误
    }
  }

  /// 暂停播报
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
    } catch (e) {
      // pause方法可能不被所有引擎支持，静默处理
    }
  }

  /// 继续播报
  Future<void> continueSpeaking() async {
    // flutter_tts 的 pause/resume 功能有限
    // 实际使用时建议重新调用speak
    // 此处为接口完整性保留
  }

  // ==================== 智能内容播报 ====================

  /// 根据内容类型生成不同播报文本并播报
  /// [contentMap] 内容对象的Map表示，包含 content, type, hint, fullText, answer 等字段
  Future<void> speakContent(Map<String, dynamic> contentMap) async {
    final content = _TtsContent.fromMap(contentMap);

    switch (content.type) {
      case _typeChineseChar:
        await _speakChineseChar(content);
        break;
      case _typeChineseWord:
        await _speakChineseWord(content);
        break;
      case _typeChinesePoem:
        await _speakChinesePoemIntro(content);
        break;
      case _typeEnglishWord:
        await _speakEnglishWord(content);
        break;
      case _typeEnglishPhrase:
        await _speakEnglishPhrase(content);
        break;
      case _typeMathQuestion:
        await _speakMathQuestion(content);
        break;
      default:
        // 未知类型，直接播报内容
        await speak(content.content);
    }
  }

  /// 播报单字听写："请听写，{hint}，{content}"
  Future<void> _speakChineseChar(_TtsContent content) async {
    final hint = content.hint?.isNotEmpty == true ? '，${content.hint}' : '';
    final text = '请听写$hint，${content.content}';
    await speak(text);
  }

  /// 播报词语听写："请听写词语，{hint}，{content}"
  Future<void> _speakChineseWord(_TtsContent content) async {
    final hint = content.hint?.isNotEmpty == true ? '，${content.hint}' : '';
    final text = '请听写词语$hint，${content.content}';
    await speak(text);
  }

  /// 播报古诗词介绍："请默写，{hint}，{content}，{fullText}"
  Future<void> _speakChinesePoemIntro(_TtsContent content) async {
    final hint = content.hint?.isNotEmpty == true ? '${content.hint}，' : '';
    final fullText = content.fullText?.isNotEmpty == true
        ? '，${content.fullText}'
        : '';
    final text = '请默写，$hint${content.content}$fullText';
    await speak(text);
  }

  /// 播报英语单词："请听写，{hint}，{content}"
  Future<void> _speakEnglishWord(_TtsContent content) async {
    final hint = content.hint?.isNotEmpty == true ? '，${content.hint}' : '';
    final text = '请听写$hint，${content.content}';
    await speak(text);
  }

  /// 播报英语短语："请听写短语，{hint}，{content}"
  Future<void> _speakEnglishPhrase(_TtsContent content) async {
    final hint = content.hint?.isNotEmpty == true ? '，${content.hint}' : '';
    final text = '请听写短语$hint，${content.content}';
    await speak(text);
  }

  /// 播报数学题："请听题，{content}"
  Future<void> _speakMathQuestion(_TtsContent content) async {
    final text = '请听题，${content.content}';
    await speak(text);
  }

  // ==================== 古诗词逐句播报 ====================

  /// 古诗词逐句停顿播报
  /// 将古诗词全文按句号、问号、感叹号、逗号分割逐句播报
  /// 每句之间有停顿间隔
  Future<void> speakPoem(Map<String, dynamic> poemMap) async {
    final poem = _TtsContent.fromMap(poemMap);
    final fullText = poem.fullText ?? poem.content;

    if (fullText.isEmpty) {
      await speak('诗词内容为空');
      return;
    }

    // 先播报标题和作者
    final intro = '请默写，${poem.hint ?? ''}，${poem.content}';
    await speak(intro);

    // 停顿一下
    await Future.delayed(const Duration(milliseconds: _kPoemLineDelayMs));

    // 逐句播报
    final lines = _splitPoemIntoLines(fullText);
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) {
        await speak(line);
        // 句间停顿
        if (i < lines.length - 1) {
          await Future.delayed(const Duration(milliseconds: _kPoemLineDelayMs));
        }
      }
    }
  }

  /// 将诗词全文分割为逐句列表
  /// 按句号、问号、感叹号、逗号、分号分割
  List<String> _splitPoemIntoLines(String text) {
    final List<String> lines = [];
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(char);

      // 遇到标点符号则切分
      if ('。，！？；、'.contains(char)) {
        final line = buffer.toString().trim();
        if (line.isNotEmpty) {
          lines.add(line);
        }
        buffer.clear();
      }
    }

    // 处理末尾没有标点的内容
    if (buffer.isNotEmpty) {
      final line = buffer.toString().trim();
      if (line.isNotEmpty) {
        lines.add(line);
      }
    }

    return lines;
  }

  // ==================== 语速控制 ====================

  /// 设置语速
  /// [rate] 语速值，范围 0.1 - 1.0
  /// 0.1为最慢，1.0为最快，默认0.5
  Future<void> setRate(double rate) async {
    _currentRate = rate.clamp(_kMinRate, _kMaxRate);

    if (!_initialized) await initialize();

    try {
      await _flutterTts.setSpeechRate(_currentRate);
      // 持久化保存
      await _saveRateToPrefs();
    } catch (e) {
      // 语速设置失败，不影响功能
    }
  }

  /// 获取当前语速
  Future<double> getRate() async {
    return _currentRate;
  }

  /// 从SharedPreferences读取语速设置
  Future<void> _loadRateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRate = prefs.getDouble(_kTtsRateKey);
      if (savedRate != null) {
        _currentRate = savedRate.clamp(_kMinRate, _kMaxRate);
      }
    } catch (e) {
      // 读取失败使用默认值
      _currentRate = _kDefaultRate;
    }
  }

  /// 保存语速设置到SharedPreferences
  Future<void> _saveRateToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kTtsRateKey, _currentRate);
    } catch (e) {
      // 保存失败静默处理
    }
  }

  // ==================== 资源释放 ====================

  /// 释放TTS资源
  void dispose() {
    try {
      _flutterTts.stop();
    } catch (e) {
      // 忽略
    }
  }
}
