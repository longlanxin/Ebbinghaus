import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

// ============================================================
// 音频录制服务 - 单例模式
// 负责数学答题录音的录制、播放和管理
// 使用 record 包录制，audioplayers 播放
// ============================================================

/// 录音文件默认保存的子目录名
const String _kRecordingDir = 'recordings';

/// 录音文件格式
const String _kRecordingFormat = '.m4a';

/// 保留的最大录音文件数量（默认30条）
const int _kDefaultKeepCount = 30;

/// 录音采样率（Hz）
const int _kSampleRate = 44100;

/// 录音比特率（bps）
const int _kBitRate = 128000;

class AudioService {
  // ==================== 单例模式 ====================
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // ==================== 成员变量 ====================

  /// 录音器实例
  final Record _recorder = Record();

  /// 音频播放器实例
  AudioPlayer? _player;

  /// 是否已初始化
  bool _initialized = false;

  /// 是否正在录音中
  bool _isRecording = false;

  /// 是否正在播放中
  bool _isPlaying = false;

  /// 当前录音文件路径
  String? _currentRecordingPath;

  /// 录音开始时间（用于计算录音时长）
  DateTime? _recordingStartTime;

  /// 录音完成回调
  Function(String filePath, Duration duration)? _onRecordingComplete;

  /// 播放状态变化回调
  Function(bool isPlaying)? _onPlayingStateChanged;

  /// 录音错误回调
  Function(String error)? _onError;

  /// 私有录音目录路径（缓存）
  String? _recordingDirectoryPath;

  // ==================== Getter ====================

  /// 是否正在录音
  bool get isRecording => _isRecording;

  /// 是否正在播放
  bool get isPlaying => _isPlaying;

  /// 当前录音文件路径
  String? get currentRecordingPath => _currentRecordingPath;

  /// 获取当前录音时长（毫秒）
  int? get currentRecordingDurationMs {
    if (_recordingStartTime == null || !_isRecording) return null;
    return DateTime.now().difference(_recordingStartTime!).inMilliseconds;
  }

  // ==================== 初始化 ====================

  /// 初始化音频服务
  /// - 请求录音权限
  /// - 创建录音文件保存目录
  /// - 初始化音频播放器
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 创建录音目录
      await _ensureRecordingDirectory();

      // 初始化播放器
      _player = AudioPlayer();

      // 监听播放器状态
      _player!.onPlayerComplete.listen((_) {
        _isPlaying = false;
        _onPlayingStateChanged?.call(false);
      });

      _player!.onPlayerStateChanged.listen((state) {
        _isPlaying = state == PlayerState.playing;
        _onPlayingStateChanged?.call(_isPlaying);
      });

      _initialized = true;
    } catch (e) {
      _initialized = true;
      _onError?.call('音频服务初始化失败: $e');
    }
  }

  // ==================== 权限管理 ====================

  /// 检查是否有录音权限
  Future<bool> hasPermission() async {
    try {
      // 使用 permission_handler 检查麦克风权限
      final status = await Permission.microphone.status;

      if (status.isGranted) {
        return true;
      }

      // 检查存储权限（Android需要）
      if (Platform.isAndroid) {
        final storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          return false;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// 请求录音权限
  /// 返回 true 表示权限已授权
  Future<bool> requestPermission() async {
    try {
      // 请求麦克风权限
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        return false;
      }

      // Android 额外请求存储权限
      if (Platform.isAndroid) {
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          // 存储权限被拒绝，不影响基本录音功能
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 确保录音目录存在
  Future<void> _ensureRecordingDirectory() async {
    if (_recordingDirectoryPath != null) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final recordingDir = Directory(path.join(appDir.path, _kRecordingDir));

      if (!await recordingDir.exists()) {
        await recordingDir.create(recursive: true);
      }

      _recordingDirectoryPath = recordingDir.path;
    } catch (e) {
      // 使用临时目录作为降级
      final tempDir = await getTemporaryDirectory();
      final recordingDir = Directory(path.join(tempDir.path, _kRecordingDir));

      if (!await recordingDir.exists()) {
        await recordingDir.create(recursive: true);
      }

      _recordingDirectoryPath = recordingDir.path;
    }
  }

  /// 获取录音文件保存路径
  Future<String> _getRecordingPath() async {
    await _ensureRecordingDirectory();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'recording_$timestamp$_kRecordingFormat';
    final filePath = path.join(_recordingDirectoryPath!, fileName);

    return filePath;
  }

  // ==================== 录音控制 ====================

  /// 开始录音
  /// 返回录音文件的保存路径
  /// 如果权限不足返回 null
  /// [onComplete] 录音完成时的回调（可选）
  Future<String?> startRecording({
    Function(String filePath, Duration duration)? onComplete,
    Function(String error)? onError,
  }) async {
    if (!_initialized) await initialize();

    // 检查权限
    final hasMicPermission = await hasPermission();
    if (!hasMicPermission) {
      final granted = await requestPermission();
      if (!granted) {
        onError?.call('没有录音权限，请在设置中开启麦克风权限');
        return null;
      }
    }

    // 如果正在录音，先停止
    if (_isRecording) {
      await stopRecording();
    }

    try {
      // 获取保存路径
      final filePath = await _getRecordingPath();
      _currentRecordingPath = filePath;
      _onRecordingComplete = onComplete;
      _onError = onError;

      // 开始录音
      await _recorder.start(
        path: filePath,
        encoder: AudioEncoder.aacLc,
        bitRate: _kBitRate,
        samplingRate: _kSampleRate,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();

      return filePath;
    } catch (e) {
      _isRecording = false;
      onError?.call('开始录音失败: $e');
      return null;
    }
  }

  /// 停止录音
  /// 返回录音文件的最终路径
  Future<String?> stopRecording() async {
    if (!_isRecording) return _currentRecordingPath;

    try {
      final filePath = await _recorder.stop();
      _isRecording = false;

      // 计算录音时长
      final duration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!)
          : Duration.zero;

      _recordingStartTime = null;

      // 调用完成回调
      if (filePath != null && _onRecordingComplete != null) {
        _onRecordingComplete!(filePath, duration);
      }

      return filePath ?? _currentRecordingPath;
    } catch (e) {
      _isRecording = false;
      _recordingStartTime = null;
      _onError?.call('停止录音失败: $e');
      return _currentRecordingPath;
    }
  }

  /// 检查是否正在录音
  /// 由于 record 包没有 isRecording() 方法，使用内部状态追踪
  Future<bool> checkRecording() async {
    return _isRecording;
  }

  // ==================== 播放控制 ====================

  /// 播放指定路径的录音文件
  /// [filePath] 录音文件路径
  /// [onComplete] 播放完成回调（可选）
  /// [onError] 播放错误回调（可选）
  Future<void> playRecording(
    String filePath, {
    void Function()? onComplete,
    Function(String error)? onError,
  }) async {
    if (!_initialized) await initialize();

    // 如果正在播放其他录音，先停止
    if (_isPlaying) {
      await stopPlaying();
    }

    try {
      // 检查文件是否存在
      final file = File(filePath);
      if (!await file.exists()) {
        onError?.call('录音文件不存在: $filePath');
        return;
      }

      // 播放录音
      await _player?.play(DeviceFileSource(filePath));
      _isPlaying = true;

      // 监听完成事件
      if (onComplete != null) {
        final subscription = _player?.onPlayerComplete.listen((_) {
          onComplete();
        });
        // 一次性监听
        Future.delayed(const Duration(seconds: 1), () {
          subscription?.cancel();
        });
      }
    } catch (e) {
      _isPlaying = false;
      onError?.call('播放录音失败: $e');
    }
  }

  /// 停止播放
  Future<void> stopPlaying() async {
    try {
      await _player?.stop();
      _isPlaying = false;
    } catch (e) {
      // 忽略停止错误
    }
  }

  // ==================== 文件管理 ====================

  /// 删除指定路径的录音文件
  /// [filePath] 要删除的文件路径
  Future<void> deleteRecording(String filePath) async {
    try {
      // 如果正在播放该文件，先停止
      if (_isPlaying && _currentRecordingPath == filePath) {
        await stopPlaying();
      }

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // 如果是当前录音路径，清空
      if (_currentRecordingPath == filePath) {
        _currentRecordingPath = null;
      }
    } catch (e) {
      // 删除失败，忽略
    }
  }

  /// 获取所有录音文件列表（按修改时间降序排列）
  /// 返回文件路径和修改时间的列表
  Future<List<Map<String, dynamic>>> getAllRecordings() async {
    try {
      await _ensureRecordingDirectory();
      final dir = Directory(_recordingDirectoryPath!);

      if (!await dir.exists()) return [];

      final files = await dir
          .list()
          .where((entity) =>
              entity is File && entity.path.endsWith(_kRecordingFormat))
          .toList();

      // 按修改时间排序（最新的在前）
      files.sort((a, b) {
        final aStat = (a as File).statSync();
        final bStat = (b as File).statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return files.map((file) {
        final stat = (file as File).statSync();
        return {
          'path': file.path,
          'size': stat.size,
          'modifiedAt': stat.modified,
          'name': path.basename(file.path),
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 清理旧录音文件
  /// [keepCount] 保留的文件数量，默认 30 条
  /// 保留最新的 keepCount 条，删除其余
  Future<int> cleanupOldRecordings(int keepCount) async {
    try {
      final recordings = await getAllRecordings();

      if (recordings.length <= keepCount) return 0;

      int deletedCount = 0;
      // 删除超出保留数量的旧文件
      for (int i = keepCount; i < recordings.length; i++) {
        final filePath = recordings[i]['path'] as String;

        // 跳过正在播放的文件
        if (_isPlaying && _currentRecordingPath == filePath) {
          continue;
        }

        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
            deletedCount++;
          }
        } catch (e) {
          // 单个文件删除失败，继续下一个
        }
      }

      return deletedCount;
    } catch (e) {
      return 0;
    }
  }

  /// 获取录音文件总数
  Future<int> getRecordingCount() async {
    try {
      final recordings = await getAllRecordings();
      return recordings.length;
    } catch (e) {
      return 0;
    }
  }

  /// 获取录音文件总大小（字节）
  Future<int> getTotalSize() async {
    try {
      final recordings = await getAllRecordings();
      int totalSize = 0;
      for (final record in recordings) {
        totalSize += record['size'] as int;
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  // ==================== 回调设置 ====================

  /// 设置播放状态变化回调
  void setPlayingStateChangedCallback(Function(bool isPlaying) callback) {
    _onPlayingStateChanged = callback;
  }

  /// 设置错误回调
  void setErrorCallback(Function(String error) callback) {
    _onError = callback;
  }

  // ==================== 资源释放 ====================

  /// 释放音频服务资源
  void dispose() {
    try {
      // 停止录音
      if (_isRecording) {
        _recorder.stop();
      }

      // 释放录音器
      _recorder.dispose();

      // 释放播放器
      _player?.dispose();
      _player = null;

      // 取消定时器
      _isRecording = false;
      _isPlaying = false;
    } catch (e) {
      // 释放资源时出错，忽略
    }
  }
}

// 使用 Flutter 内置的 VoidCallback (typedef void Function())
