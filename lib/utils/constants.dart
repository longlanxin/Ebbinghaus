// lib/utils/constants.dart
// 艾宾浩斯记忆助手 - 全局常量定义
// 包含：类型枚举、状态枚举、艾宾浩斯间隔、阈值、默认配置、语音关键词、配色常量

// ============================================================
// 内容类型枚举字符串
// ============================================================

/// 语文单字类型
const String typeChineseChar = 'chinese_char';

/// 语文词语类型
const String typeChineseWord = 'chinese_word';

/// 语文古诗词类型
const String typeChinesePoem = 'chinese_poem';

/// 古诗词错字类型（从原诗提取的薄弱字）
const String typePoemChar = 'poem_char';

/// 英语单词类型
const String typeEnglishWord = 'english_word';

/// 英语短语类型
const String typeEnglishPhrase = 'english_phrase';

/// 数学问题类型
const String typeMathQuestion = 'math_question';

/// 所有内容类型的列表
const List<String> kAllContentTypes = [
  typeChineseChar,
  typeChineseWord,
  typeChinesePoem,
  typePoemChar,
  typeEnglishWord,
  typeEnglishPhrase,
  typeMathQuestion,
];

/// 内容类型显示名称映射
const Map<String, String> kContentTypeDisplayNames = {
  typeChineseChar: '语文单字',
  typeChineseWord: '语文词语',
  typeChinesePoem: '古诗词',
  typePoemChar: '错字',
  typeEnglishWord: '英语单词',
  typeEnglishPhrase: '英语短语',
  typeMathQuestion: '数学问题',
};

// ============================================================
// 学习状态枚举字符串
// ============================================================

/// 新词状态（刚导入，尚未开始学习）
const String statusNewWord = 'new_word';

/// 学习中状态（正在进行艾宾浩斯复习循环）
const String statusLearning = 'learning';

/// 已掌握状态（连续正确次数达到掌握阈值）
const String statusMastered = 'mastered';

/// 困难状态（错误次数达到困难阈值）
const String statusDifficult = 'difficult';

/// 所有状态枚举的列表
const List<String> kAllStatuses = [
  statusNewWord,
  statusLearning,
  statusMastered,
  statusDifficult,
];

/// 状态显示名称映射
const Map<String, String> kStatusDisplayNames = {
  statusNewWord: '新词',
  statusLearning: '学习中',
  statusMastered: '已掌握',
  statusDifficult: '困难',
};

// ============================================================
// 艾宾浩斯遗忘曲线间隔序列
// 第1次：当天（间隔0天）
// 第2次：隔天（间隔1天）
// 第3次：第3天（间隔1天）
// 第4次：第7天（间隔2天）
// 第5次：第14天（间隔4天）
// 第6次：第30天（间隔7天）
// 第7次+：每30天（间隔15天或30天）
// ============================================================

/// 艾宾浩斯标准间隔序列（天数）
const List<int> kEbbinghausIntervals = [1, 1, 2, 4, 7, 15, 30];

/// 间隔序列的最大索引（超过此索引后使用最后一个值）
const int kMaxIntervalIndex = 6;

// ============================================================
// 阈值常量
// ============================================================

/// 掌握阈值：连续正确达到此次数，内容标记为已掌握
const int kMasterThreshold = 5;

/// 困难阈值：错误次数达到此次数，内容标记为困难
const int kDifficultThreshold = 2;

/// 错字掌握阈值：错字连续正确达到此次数，从薄弱库移除
const int kPoemCharMasterThreshold = 3;

// ============================================================
// 默认配置值
// ============================================================

/// 每日最大任务数量（含所有类型）
const int kMaxDailyTasks = 15;

/// 每日最多加练困难词数量
const int kMaxDifficultWords = 3;

/// 每周数学抽查次数上限
const int kMathQuizzesPerWeek = 2;

/// TTS默认播报语速（0.0 ~ 1.0）
const double kDefaultTTSRate = 0.5;

/// 听写完成后自动播放下一项的延迟（秒）
const int kAutoAdvanceDelaySeconds = 5;

/// 默认每日最大任务数（可在设置中调整）
const int kDefaultMaxDailyTasks = 15;

/// 默认播报间隔时间（秒）
const int kDefaultSpeakIntervalSeconds = 5;

// ============================================================
// 语音关键词列表（8组命令，用于语音控制）
// ============================================================

/// 开始听写命令
const List<String> kStartCommands = ['开始', '开始听写'];

/// 重复播报命令
const List<String> kRepeatCommands = ['再说一遍', '重复'];

/// 放慢语速命令
const List<String> kSlowerCommands = ['慢一点', '太快了'];

/// 加快语速命令
const List<String> kFasterCommands = ['快一点'];

/// 完成听写命令
const List<String> kFinishCommands = ['我完成了', '写完了'];

/// 标记正确命令
const List<String> kCorrectCommands = ['正确', '对的'];

/// 标记错误命令
const List<String> kWrongCommands = ['错了', '这个字错了'];

/// 下一个命令
const List<String> kNextCommands = ['下一个'];

/// 提交结果命令
const List<String> kSubmitCommands = ['提交'];

/// 所有语音命令的集合（用于快速查找匹配）
const Map<String, List<String>> kAllVoiceCommands = {
  'start': kStartCommands,
  'repeat': kRepeatCommands,
  'slower': kSlowerCommands,
  'faster': kFasterCommands,
  'finish': kFinishCommands,
  'correct': kCorrectCommands,
  'wrong': kWrongCommands,
  'next': kNextCommands,
  'submit': kSubmitCommands,
};

// ============================================================
// 配色常量（护眼配色方案）
// ============================================================

/// 主色调 - 护眼绿（Material Green 500）
const int kPrimaryColor = 0xFF4CAF50;

/// 背景色 - 暖白/米黄（保护视力）
const int kBackgroundColor = 0xFFFFF8E1;

/// 强调色 - 橙色（Material Orange 500）
const int kAccentColor = 0xFFFF9800;

/// 正确色 - 绿色（Material Green 500）
const int kCorrectColor = 0xFF4CAF50;

/// 错误色 - 红色（Material Red 500）
const int kWrongColor = 0xFFF44336;

/// 困难词颜色 - 深橙（Material Deep Orange 500）
const int kDifficultColor = 0xFFFF5722;

/// 主文本色 - 深灰
const int kTextPrimaryColor = 0xFF212121;

/// 次要文本色 - 灰色
const int kTextSecondaryColor = 0xFF757575;

/// 听写页背景色 - 纯黑（减少干扰）
const int kDictationBackgroundColor = 0xFF000000;

/// 听写页文字色 - 白色
const int kDictationTextColor = 0xFFFFFFFF;

/// 古诗词逐字核对 - 未标记色（灰色）
const int kPoemCharUnmarkedColor = 0xFF9E9E9E;

/// 古诗词逐字核对 - 正确标记色（绿色）
const int kPoemCharCorrectColor = 0xFF4CAF50;

/// 古诗词逐字核对 - 错误标记色（红色）
const int kPoemCharWrongColor = 0xFFF44336;

/// 蓝色按钮（用于"下一个"、"提交"等操作）
const int kBlueButtonColor = 0xFF2196F3;

/// 黄色按钮（用于"重复"操作）
const int kYellowButtonColor = 0xFFFFEB3B;

// ============================================================
// 家长模式验证
// ============================================================

/// 家长模式长按触发时间（毫秒）
const int kParentModeLongPressDuration = 3000;

/// 家长模式验证问题难度（两位数以内加法）
const int kParentModeMaxNum = 20;

// ============================================================
// 时间相关常量
// ============================================================

/// 结果页自动返回延迟（秒）
const int kResultAutoReturnSeconds = 3;

/// 旧录音清理保留天数
const int kKeepRecordingsDays = 30;

/// 最近打卡天数统计（用于学习报告）
const int kRecentCheckInDays = 7;

/// 数学录音评分结果 - 理解了
const String kRatingUnderstood = 'understood';

/// 数学录音评分结果 - 有点模糊
const String kRatingFuzzy = 'fuzzy';

/// 数学录音评分结果 - 不太懂
const String kRatingConfused = 'confused';
