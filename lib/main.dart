import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 全局应用状态管理
import 'providers/app_state.dart';

// 服务层：TTS语音播报、语音识别、音频录制
import 'services/tts_service.dart';
import 'services/speech_service.dart';
import 'services/audio_service.dart';

// 首页
import 'screens/home_screen.dart';

/// 应用程序入口函数
/// 
/// 使用 async 确保所有异步初始化完成后再启动应用。
/// WidgetsFlutterBinding.ensureInitialized() 必须在 runApp 之前调用，
/// 以确保 Flutter 框架已准备好与平台通道通信。
void main() async {
  // 确保 Flutter Widget 绑定已初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化所有核心服务
  // 使用 try-catch 包裹每个服务的初始化，防止单个服务失败导致 APP 崩溃
  await _initializeServices();

  // 启动应用，使用 MultiProvider 包裹 MaterialApp
  // 以便全局共享应用状态
  runApp(
    MultiProvider(
      providers: [
        // 全局应用状态管理器（ChangeNotifier）
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const MyApp(),
    ),
  );
}

/// 初始化所有第三方服务
/// 
/// 包括：
/// - TTS 语音播报服务（flutter_tts）
/// - 语音识别服务（speech_to_text）
/// - 音频录制服务（record）
/// 
/// 每个服务独立初始化，失败不会阻塞其他服务。
Future<void> _initializeServices() async {
  // ===== 初始化 TTS 语音播报服务 =====
  try {
    final ttsService = TTSService();
    await ttsService.initialize();
    debugPrint('TTS 语音播报服务初始化成功');
  } catch (e) {
    debugPrint('TTS 语音播报服务初始化失败: $e');
    // TTS 初始化失败不影响应用启动，后续使用时再尝试
  }

  // ===== 初始化语音识别服务 =====
  try {
    final speechService = SpeechService();
    await speechService.initialize();
    debugPrint('语音识别服务初始化成功');
  } catch (e) {
    debugPrint('语音识别服务初始化失败: $e');
  }

  // ===== 初始化音频录制服务 =====
  try {
    final audioService = AudioService();
    await audioService.initialize();
    debugPrint('音频录制服务初始化成功');
  } catch (e) {
    debugPrint('音频录制服务初始化失败: $e');
  }
}

/// 应用根组件
/// 
/// 配置 MaterialApp 的全局主题、路由和基础样式。
/// 针对小学三年级学生（8-9岁）做了大字体、大按钮、护眼配色等适配。
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 应用标题（在任务切换器中显示）
      title: '小蜜蜂记忆助手',

      // 关闭调试模式横幅
      debugShowCheckedModeBanner: false,

      // ===== 全局主题配置 =====
      theme: ThemeData(
        // 主色调：护眼绿色（#4CAF50）
        primarySwatch: Colors.green,

        // 脚手架（页面）背景色：暖白色（#FFF8E1）
        // 护眼设计，降低蓝光刺激
        scaffoldBackgroundColor: const Color(0xFFFFF8E1),

        // 中文字体：Noto Sans SC（思源黑体）
        // 确保中文显示清晰，适合儿童阅读
        fontFamily: 'NotoSansSC',

        // ===== 大字体文字主题（适配儿童视力） =====
        textTheme: const TextTheme(
          // 页面大标题：32sp，加粗，深灰色
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
            letterSpacing: 1.0,
          ),
          // 页面标题：28sp，加粗
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
          // 小标题：24sp，加粗
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
          // 正文大字：20sp，常规
          bodyLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.normal,
            color: Color(0xFF212121),
          ),
          // 正文中字：18sp
          bodyMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.normal,
            color: Color(0xFF212121),
          ),
          // 小字/辅助文字：16sp，灰色
          bodySmall: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: Color(0xFF757575),
          ),
          // 按钮文字：24sp，加粗，白色
          labelLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),

        // ===== 大按钮主题（适配儿童手指点击） =====
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            // 最小高度 64dp，确保按钮足够大，容易点击
            minimumSize: const Size(double.infinity, 64),
            // 圆角 16dp，圆润友好的视觉效果
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            // 内边距，按钮内部文字有足够的空间
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 16,
            ),
            // 按钮文字样式
            textStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'NotoSansSC',
            ),
            // 默认背景色：护眼绿色
            backgroundColor: const Color(0xFF4CAF50),
            // 禁用状态的颜色
            disabledBackgroundColor: const Color(0xFFBDBDBD),
            disabledForegroundColor: Colors.white70,
          ),
        ),

        // 浮动操作按钮主题
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          extendedTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSansSC',
          ),
        ),

        // 卡片主题
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(8),
        ),

        // 应用栏主题
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSansSC',
            color: Colors.white,
          ),
          backgroundColor: Color(0xFF4CAF50),
          elevation: 0,
        ),

        // 对话框主题
        dialogTheme: DialogTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSansSC',
            color: Color(0xFF212121),
          ),
          contentTextStyle: const TextStyle(
            fontSize: 18,
            fontFamily: 'NotoSansSC',
            color: Color(0xFF212121),
          ),
        ),

        // 输入框主题
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: const TextStyle(
            fontSize: 18,
            fontFamily: 'NotoSansSC',
          ),
          hintStyle: const TextStyle(
            fontSize: 18,
            fontFamily: 'NotoSansSC',
            color: Color(0xFF757575),
          ),
        ),

        // 滑块主题
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFF4CAF50),
          inactiveTrackColor: Color(0xFFBBDEFB),
          thumbColor: Color(0xFF4CAF50),
          overlayColor: Color(0x294CAF50),
          trackHeight: 8,
        ),
      ),

      // ===== 首页路由 =====
      home: const HomeScreen(),
    );
  }
}
