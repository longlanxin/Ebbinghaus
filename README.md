# 小蜜蜂记忆助手 (Ebbinghaus Memory Helper)

> 基于艾宾浩斯遗忘曲线的小学三年级听写APP，纯离线，零服务器成本。

## 项目统计

| 指标 | 数值 |
|------|------|
| Dart代码文件 | 36个 |
| Dart代码总行数 | 12,939行 |
| 配置文件 | 4个 |
| 数据表 | 5个 |
| UI页面 | 12个 |
| 服务模块 | 4个 |
| TODO剩余 | 0个 |

## 技术栈

- **Framework**: Flutter 3.x
- **Database**: SQLite (sqflite)
- **TTS**: flutter_tts（语音播报）
- **Speech Recognition**: speech_to_text（语音指令）
- **Audio Recording**: record（数学录音）
- **State Management**: Provider
- **Other**: file_picker, csv, uuid, intl, shared_preferences, audioplayers

## 项目结构

```
lib/
├── main.dart                           # 应用入口
├── models/                             # 数据模型（5个模型类）
│   ├── content.dart                    # 学习内容
│   ├── schedule.dart                   # 艾宾浩斯调度
│   ├── poem_error.dart                 # 古诗词错字
│   ├── check_in.dart                   # 打卡记录
│   ├── math_recording.dart             # 数学录音
│   └── daily_task.dart                 # 每日任务/核对结果
├── database/                           # 数据库层
│   └── database_helper.dart            # SQLite单例（1,252行，45个方法）
├── services/                           # 服务层
│   ├── tts_service.dart                # TTS语音播报
│   ├── speech_service.dart             # 语音关键词识别
│   ├── audio_service.dart              # 音频录制
│   └── csv_import_service.dart         # CSV批量导入
├── providers/                          # 业务逻辑
│   ├── app_state.dart                  # 全局状态管理
│   ├── schedule_manager.dart           # 艾宾浩斯调度算法
│   └── task_generator.dart             # 每日任务生成
├── screens/                            # UI页面（12个页面）
│   ├── home_screen.dart                # 首页
│   ├── dictation_screen.dart           # 听写黑屏页
│   ├── check_screen.dart               # 通用核对页
│   ├── poem_check_screen.dart          # 古诗词逐字核对
│   ├── result_screen.dart              # 结果页
│   ├── parent_screen.dart              # 家长模式
│   ├── import_screen.dart              # CSV导入
│   ├── report_screen.dart              # 学习报告
│   ├── difficult_words_screen.dart     # 困难词列表
│   ├── math_recording_screen.dart      # 数学录音评分
│   └── settings_screen.dart            # 设置
├── widgets/                            # 可复用组件
│   ├── big_button.dart                 # 大按钮
│   ├── eye_protection_container.dart   # 护眼容器
│   └── speech_hint_bar.dart            # 语音指令提示
└── utils/                              # 工具类
    ├── constants.dart                  # 常量定义
    ├── ebbinghaus.dart                 # 艾宾浩斯间隔计算
    └── validators.dart                 # 验证工具
```

## 核心功能

### 1. 艾宾浩斯记忆调度
- 7级间隔序列：1, 1, 2, 4, 7, 15, 30天
- 动态间隔调整：正确推进，错误缩短50%
- 连续正确5次标记为"已掌握"
- 错误2次标记为"困难词"
- 古诗词错字自动提取为独立学习内容

### 2. 每日任务生成（4级优先级）
1. 困难词加练（最多3个）
2. 到期复习项（按errorCount排序）
3. 新学内容
4. 数学抽查（每周最多2次）
总量不超过15个，预计15分钟内完成

### 3. 语音播报（TTS）
- 根据内容类型生成不同播报文本
- 古诗词逐句停顿播报
- 语速可调（0.1-1.0）
- TTS不可用时降级为屏幕显示

### 4. 语音指令识别（离线关键词）
支持9组关键词：开始、再说一遍/重复、慢一点/太快了、快一点、我完成了/写完了、正确/对的、错了/这个字错了、下一个、提交

### 5. CSV批量导入（4种格式）
- 语文模板（chinese.csv）：生字、词语
- 英语模板（english.csv）：单词、短语
- 古诗词模板（poems.csv）：古诗词全文
- 数学模板（math.csv）：数学概念问答题

### 6. 家长模式
- 长按3秒+算术验证进入
- CSV导入/学习报告/困难词列表/数学录音评分/设置

### 7. 数学问答录音
- 语音提问→孩子口述回答→录音保存
- 家长异步评分：理解/模糊/不懂
- 评分影响后续出题频率

## 快速开始

### 环境要求
- Flutter 3.0+
- Dart 3.0+
- Android SDK 21+

### 构建步骤

```bash
# 1. 解压项目
cd ebbinghaus_memory_helper

# 2. 获取依赖
flutter pub get

# 3. 构建Android APK
flutter build apk --release

# 4. 安装到设备
flutter install
```

### 开发调试

```bash
# 运行到连接的设备
flutter run

# 运行测试
flutter test

# 代码分析
flutter analyze
```

## 数据模型

### 5个核心数据表

| 表名 | 用途 | 核心字段 |
|------|------|----------|
| `contents` | 学习内容主表 | content, type, hint, full_text, source |
| `schedules` | 艾宾浩斯调度表 | content_id, next_review_date, interval_days, status |
| `poem_errors` | 古诗词错字明细 | poem_id, char_index, standard_char, wrong_char |
| `check_ins` | 打卡记录 | date, task_count, correct_count, wrong_count |
| `math_recordings` | 数学录音 | content_id, file_path, parent_rating |

### 内容类型（7种）
- `chinese_char` - 中文字（生字）
- `chinese_word` - 中文词语
- `chinese_poem` - 古诗词
- `poem_char` - 古诗词错字（自动生成）
- `english_word` - 英语单词
- `english_phrase` - 英语短语
- `math_question` - 数学问答题

## CSV导入格式

### 语文模板（chinese.csv）
```csv
content,type,hint,context,source
鸳鸯,chinese_char,拼音：yuān yāng 一种水鸟,沙暖睡鸳鸯,三下第1课
吹拂,chinese_word,春风吹拂着柳枝,春风轻轻地吹拂着大地,三下第1课
```

### 英语模板（english.csv）
```csv
content,type,hint,context,source
have lunch,english_word,/hæv lʌntʃ/ 吃午饭,I have lunch at 12 o'clock.,Unit 1
go to school,english_phrase,去上学,I go to school by bus.,Unit 1
```

### 古诗词模板（poems.csv）
```csv
content,type,hint,full_text,source
绝句,chinese_poem,唐代 杜甫,两个黄鹂鸣翠柳，一行白鹭上青天。窗含西岭千秋雪，门泊东吴万里船。,三下第1课
```

### 数学模板（math.csv）
```csv
content,type,hint,answer,source
边长4厘米的正方形，周长和面积都是16，它们一样吗？为什么？,math_question,注意单位,不一样。周长是16厘米，面积是16平方厘米。单位不同。,三下第5课
```

## 边界处理

1. **TTS不可用**：首次启动检测，未安装中文语音包时引导用户去系统设置下载。播报失败降级为屏幕显示+震动提示。
2. **语音识别不可用**：设备不支持或权限被拒时，隐藏语音指令提示，改为纯点击交互。
3. **古诗词未标记字**：提交时弹窗提示"还有X个字没核对"，可选择"回去核对"或"这些我都写对了"。
4. **今日无任务**：首页显示"今天没有任务，休息一天"，TTS播报"今天休息，去外面玩吧"。
5. **重复导入**：根据content+source联合去重，提示"已存在，跳过或覆盖"。
6. **CSV格式错误**：显示具体错误行号和原因，其他正确行正常导入。
7. **多天未打开**：逾期复习项不增加错误计数，堆积到下次打开时一并处理，避免惩罚感。
8. **家长模式防误触**：长按3秒+简单算术验证（如"3+5=?"）。
9. **数学录音管理**：录音保存于应用私有目录，保留最近30条，超期自动清理。
10. **清除数据**：设置页面提供红色危险按钮，需二次确认。

## 配色方案

| 用途 | 颜色值 |
|------|--------|
| 主色（护眼绿） | #4CAF50 |
| 背景色（暖白） | #FFF8E1 |
| 强调色（橙色） | #FF9800 |
| 正确色（绿色） | #4CAF50 |
| 错误色（红色） | #F44336 |
| 困难色（深橙） | #FF5722 |
| 听写页背景 | #000000 |
| 听写页文字 | #FFFFFF |

## 开发团队

基于AI辅助开发，遵循需求规格说明书实现。

## 许可证

MIT License
