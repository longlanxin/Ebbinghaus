import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

// ============================================================
// 语音关键词识别服务 - 单例模式
// 负责语音识别和语音指令解析，全程无需触碰屏幕
// ============================================================

// ==================== 语音指令常量 ====================

/// 开始听写指令
const List<String> _kStartCommands = ['开始', '开始听写'];

/// 重复当前指令
const List<String> _kRepeatCommands = ['再说一遍', '重复'];

/// 语速调慢指令
const List<String> _kSlowerCommands = ['慢一点', '太快了'];

/// 语速调快指令
const List<String> _kFasterCommands = ['快一点'];

/// 完成听写指令
const List<String> _kFinishCommands = ['我完成了', '写完了'];

/// 标记正确指令
const List<String> _kCorrectCommands = ['正确', '对的'];

/// 标记错误指令
const List<String> _kWrongCommands = ['错了', '这个字错了'];

/// 下一个指令
const List<String> _kNextCommands = ['下一个'];

/// 提交指令
const List<String> _kSubmitCommands = ['提交'];

/// 识别超时时间（毫秒），超过此时间无新结果则自动停止
const int _kListenTimeoutMs = 5000;

/// 语音识别的地区代码（中文）
const String _kLocaleId = 'zh_CN';

// ==================== 语音指令枚举 ====================

/// 定义所有支持的语音指令类型
enum VoiceCommand {
  /// 开始听写
  start,

  /// 重复当前
  repeat,

  /// 语速调慢
  slower,

  /// 语速调快
  faster,

  /// 完成当前
  finish,

  /// 标记正确
  correct,

  /// 标记错误
  wrong,

  /// 下一个
  next,

  /// 提交
  submit,

  /// 未知/未匹配指令
  unknown,
}

/// 语音指令结果
class CommandResult {
  /// 指令类型
  final VoiceCommand command;

  /// 原始识别文字
  final String rawText;

  /// 识别置信度（如引擎提供）
  final double? confidence;

  /// 识别时间
  final DateTime recognizedAt;

  CommandResult({
    required this.command,
    required this.rawText,
    this.confidence,
    DateTime? recognizedAt,
  }) : recognizedAt = recognizedAt ?? DateTime.now();
}

class SpeechService {
  // ==================== 单例模式 ====================
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  // ==================== 成员变量 ====================

  /// SpeechToText实例
  final SpeechToText _speechToText = SpeechToText();

  /// 是否已初始化
  bool _initialized = false;

  /// 语音识别是否可用
  bool _isAvailable = false;

  /// 是否有录音权限
  bool _hasPermission = false;

  /// 是否正在监听
  bool _isListening = false;

  /// 命令流控制器
  StreamController<CommandResult>? _commandController;

  /// 识别结果流
  StreamController<String>? _resultController;

  /// 监听超时定时器
  Timer? _listenTimeoutTimer;

  /// 最后一次识别的文字（用于去重）
  String _lastRecognizedText = '';

  /// 同一识别文本的重复次数（用于防抖）
  int _repeatCount = 0;

  /// 上一次识别结果的时间
  DateTime? _lastRecognizeTime;

  // ==================== Getter ====================

  /// 是否正在监听中
  bool get isListening => _isListening;

  /// 语音识别是否可用
  bool get isAvailable => _isAvailable;

  /// 命令流（供外部订阅）
  Stream<CommandResult> get commandStream {
    _commandController ??= StreamController<CommandResult>.broadcast();
    return _commandController!.stream;
  }

  /// 原始识别结果流
  Stream<String> get resultStream {
    _resultController ??= StreamController<String>.broadcast();
    return _resultController!.stream;
  }

  // ==================== 初始化 ====================

  /// 初始化语音识别服务
  /// - 检测系统是否支持语音识别
  /// - 检查并请求权限
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 先检查权限
      _hasPermission = await hasPermission();

      // 初始化SpeechToText
      _isAvailable = await _speechToText.initialize(
        onError: (error) => _handleError(error),
        onStatus: (status) => _handleStatus(status),
      );

      _initialized = true;
    } catch (e) {
      _isAvailable = false;
      _initialized = true;
    }
  }

  // ==================== 状态/错误处理 ====================

  /// 处理语音识别状态变化
  void _handleStatus(String status) {
    switch (status) {
      case 'listening':
        _isListening = true;
        break;
      case 'notListening':
        _isListening = false;
        break;
      case 'done':
        _isListening = false;
        break;
      default:
        break;
    }
  }

  /// 处理语音识别错误
  void _handleError(dynamic error) {
    // 如果是超时错误，自动重新开始监听
    if (error != null && error.toString().contains('timeout')) {
      // 超时后不做任何事，等待下一次调用startListening
    }
  }

  // ==================== 权限管理 ====================

  /// 检查是否有录音权限
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    _hasPermission = status.isGranted;
    return _hasPermission;
  }

  /// 请求录音权限
  /// 返回 true 表示权限已授权
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      _hasPermission = status.isGranted;
      return _hasPermission;
    } catch (e) {
      return false;
    }
  }

  // ==================== 可用性检查 ====================

  /// 检查语音识别是否可用
  /// 需要同时满足：已初始化、系统支持、有权限
  Future<bool> checkAvailable() async {
    if (!_initialized) {
      await initialize();
    }
    if (!_hasPermission) {
      _hasPermission = await hasPermission();
    }
    return _isAvailable && _hasPermission;
  }

  // ==================== 监听控制 ====================

  /// 开始语音监听
  /// [onResult] 回调函数，每次识别到新文字时触发
  /// [onCommand] 可选的命令回调，当识别到特定指令时触发
  ///
  /// 使用示例：
  /// ```dart
  /// speechService.startListening(
  ///   onResult: (text) => print('识别到: $text'),
  ///   onCommand: (cmd) => print('指令: $cmd'),
  /// );
  /// ```
  void startListening({
    Function(String)? onResult,
    Function(VoiceCommand)? onCommand,
  }) {
    if (!_initialized) {
      return;
    }

    if (!_hasPermission) {
      return;
    }

    if (_isListening) {
      // 已经在监听了，先停止
      stopListening();
    }

    try {
      _isListening = true;
      _lastRecognizedText = '';
      _repeatCount = 0;

      // 开始监听
      _speechToText.listen(
        onResult: (result) {
          _handleListenResult(result, onResult, onCommand);
        },
        localeId: _kLocaleId,
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: false,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
      );

      // 启动超时定时器
      _startTimeoutTimer();
    } catch (e) {
      _isListening = false;
    }
  }

  /// 处理监听结果
  void _handleListenResult(
    dynamic result,
    Function(String)? onResult,
    Function(VoiceCommand)? onCommand,
  ) {
    if (result == null) return;

    try {
      // 获取识别的文字
      String recognizedText = '';
      double? confidence;

      // speech_to_text 返回 SpeechRecognitionResult 对象
      if (result is SpeechRecognitionResult) {
        recognizedText = result.recognizedWords;
        confidence = result.confidence;
      } else if (result is Map) {
        recognizedText = result['recognizedWords']?.toString() ?? '';
      }

      if (recognizedText.isEmpty) return;

      // 重置超时定时器
      _resetTimeoutTimer();

      // 防抖处理：如果识别文字和上次一样且时间间隔很短，则忽略
      final now = DateTime.now();
      if (recognizedText == _lastRecognizedText &&
          _lastRecognizeTime != null &&
          now.difference(_lastRecognizeTime!).inMilliseconds < 500) {
        return;
      }

      // 检查是否有新增内容
      if (recognizedText != _lastRecognizedText) {
        _lastRecognizedText = recognizedText;
        _lastRecognizeTime = now;
        _repeatCount = 0;
      }

      // 发送到原始结果流
      _resultController?.add(recognizedText);

      // 调用结果回调
      if (onResult != null) {
        onResult(recognizedText);
      }

      // 解析指令
      final command = _parseCommand(recognizedText);
      if (command != VoiceCommand.unknown) {
        final commandResult = CommandResult(
          command: command,
          rawText: recognizedText,
          confidence: confidence,
        );

        // 发送到命令流
        _commandController?.add(commandResult);

        // 调用命令回调
        if (onCommand != null) {
          onCommand(command);
        }
      }
    } catch (e) {
      // 处理结果时出错，忽略
    }
  }

  /// 启动超时定时器
  void _startTimeoutTimer() {
    _cancelTimeoutTimer();
    _listenTimeoutTimer = Timer(
      const Duration(milliseconds: _kListenTimeoutMs),
      () {
        // 超时后如果还在监听，自动停止
        if (_isListening) {
          stopListening();
        }
      },
    );
  }

  /// 重置超时定时器
  void _resetTimeoutTimer() {
    _startTimeoutTimer();
  }

  /// 取消超时定时器
  void _cancelTimeoutTimer() {
    _listenTimeoutTimer?.cancel();
    _listenTimeoutTimer = null;
  }

  /// 停止语音监听
  void stopListening() {
    try {
      _isListening = false;
      _cancelTimeoutTimer();

      if (_speechToText.isListening) {
        _speechToText.stop();
      }
    } catch (e) {
      // 停止时出错，忽略
    }
  }

  // ==================== 关键词匹配 ====================

  /// 从识别文字中解析指令
  /// 返回匹配的指令类型，未匹配返回 unknown
  VoiceCommand _parseCommand(String text) {
    final normalized = text.trim();

    if (_kStartCommands.any((cmd) => normalized.contains(cmd))) {
      return VoiceCommand.start;
    }

    if (_kRepeatCommands.any((cmd) => normalized.contains(cmd))) {
      return VoiceCommand.repeat;
    }

    if (_kSlowerCommands.any((cmd) => normalized.contains(cmd))) {
      return VoiceCommand.slower;
    }

    if (_kFasterCommands.any((cmd) => normalized.contains(cmd))) {
      return VoiceCommand.faster;
    }

    if (_kFinishCommands.any((cmd) => normalized.contains(cmd))) {
      return VoiceCommand.finish;
    }

    if (_kCorrectCommands.any((cmd) => normalized.contains(cmd))) {
      return VoiceCommand.correct;
    }

    if (_kWrongCommands.any((cmd) => normalized.contains(cmd))) {
      return VoiceCommand.wrong;
    }

    if (_kNextCommands.any((cmd) => normalized.contains(cmd))) {
      return VoiceCommand.next;
    }

    if (_kSubmitCommands.any((cmd) => normalized.contains(cmd))) {
      return VoiceCommand.submit;
    }

    return VoiceCommand.unknown;
  }

  /// 获取指令的中文描述（用于调试和UI显示）
  static String commandToString(VoiceCommand command) {
    switch (command) {
      case VoiceCommand.start:
        return '开始';
      case VoiceCommand.repeat:
        return '再说一遍';
      case VoiceCommand.slower:
        return '慢一点';
      case VoiceCommand.faster:
        return '快一点';
      case VoiceCommand.finish:
        return '我完成了';
      case VoiceCommand.correct:
        return '正确';
      case VoiceCommand.wrong:
        return '错了';
      case VoiceCommand.next:
        return '下一个';
      case VoiceCommand.submit:
        return '提交';
      case VoiceCommand.unknown:
        return '未知指令';
    }
  }

  /// 获取所有可用指令提示（用于UI展示）
  List<String> getAvailableCommandHints() {
    return [
      '开始',
      '再说一遍',
      '慢一点',
      '快一点',
      '我完成了',
      '正确',
      '错了',
      '下一个',
      '提交',
    ];
  }

  // ==================== 资源释放 ====================

  /// 释放语音识别资源
  void dispose() {
    try {
      _cancelTimeoutTimer();
      stopListening();
      _commandController?.close();
      _resultController?.close();
      _speechToText.cancel();
    } catch (e) {
      // 释放资源时出错，忽略
    }
  }
}
