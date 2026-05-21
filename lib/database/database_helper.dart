// lib/database/database_helper.dart
// SQLite数据库助手类 - 单例模式
// 提供所有表的CRUD操作、索引、事务支持和工具方法

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

/// 数据库助手类（单例模式）
/// 管理SQLite数据库的连接、表的创建、所有CRUD操作
class DatabaseHelper {
  // ==================== 单例模式实现 ====================

  /// 私有构造函数，防止外部实例化
  DatabaseHelper._privateConstructor();

  /// 单例实例
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  /// 数据库实例（懒加载）
  static Database? _database;

  /// 数据库文件名
  static const String _databaseName = 'ebbinghaus_memory.db';

  /// 数据库版本号
  static const int _databaseVersion = 1;

  // ==================== 表名常量 ====================

  /// 学习内容主表
  static const String tableContents = 'contents';

  /// 艾宾浩斯调度表
  static const String tableSchedules = 'schedules';

  /// 古诗词错字明细表
  static const String tablePoemErrors = 'poem_errors';

  /// 打卡记录表
  static const String tableCheckIns = 'check_ins';

  /// 数学问答录音表
  static const String tableMathRecordings = 'math_recordings';

  // ==================== contents表列名 ====================

  static const String colId = 'id';
  static const String colContent = 'content';
  static const String colType = 'type';
  static const String colParentId = 'parent_id';
  static const String colCharIndex = 'char_index';
  static const String colFullText = 'full_text';
  static const String colHint = 'hint';
  static const String colAnswer = 'answer';
  static const String colContext = 'context';
  static const String colSource = 'source';
  static const String colCreatedAt = 'created_at';

  // ==================== schedules表列名 ====================

  static const String colContentId = 'content_id';
  static const String colNextReviewDate = 'next_review_date';
  static const String colIntervalDays = 'interval_days';
  static const String colErrorCount = 'error_count';
  static const String colConsecutiveCorrect = 'consecutive_correct';
  static const String colStatus = 'status';
  static const String colLastResult = 'last_result';
  static const String colUpdatedAt = 'updated_at';

  // ==================== poem_errors表列名 ====================

  static const String colPoemId = 'poem_id';
  static const String colStandardChar = 'standard_char';
  static const String colWrongChar = 'wrong_char';
  static const String colErrorDate = 'error_date';
  static const String colReviewCount = 'review_count';

  // ==================== check_ins表列名 ====================

  static const String colDate = 'date';
  static const String colTaskCount = 'task_count';
  static const String colCorrectCount = 'correct_count';
  static const String colWrongCount = 'wrong_count';
  static const String colDurationMinutes = 'duration_minutes';

  // ==================== math_recordings表列名 ====================

  static const String colFilePath = 'file_path';
  static const String colRecordedAt = 'recorded_at';
  static const String colParentRating = 'parent_rating';
  static const String colRatedAt = 'rated_at';

  // ==================== 数据库实例获取 ====================

  /// 获取数据库实例（懒加载，首次调用时初始化）
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  // ==================== 数据库初始化 ====================

  /// 初始化数据库
  /// 打开或创建数据库文件，设置版本号，注册创建和升级回调
  Future<Database> _initDatabase() async {
    // 获取应用文档目录路径
    final documentsDirectory = await getApplicationDocumentsDirectory();
    // 拼接数据库文件的完整路径
    final dbPath = join(documentsDirectory.path, _databaseName);

    // 打开数据库，指定版本号和回调函数
    return await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        // 数据库打开时的额外操作
        // 开启外键约束支持
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// 数据库首次创建时调用
  /// 创建所有表和索引
  Future<void> _onCreate(Database db, int version) async {
    // -------------------- 创建contents表 --------------------
    // 学习内容主表，存储所有需要学习的字词、诗句、英语、数学题等
    await db.execute('''
      CREATE TABLE $tableContents (
        $colId TEXT PRIMARY KEY,
        $colContent TEXT NOT NULL,
        $colType TEXT NOT NULL,
        $colParentId TEXT,
        $colCharIndex INTEGER,
        $colFullText TEXT,
        $colHint TEXT,
        $colAnswer TEXT,
        $colContext TEXT,
        $colSource TEXT NOT NULL DEFAULT '',
        $colCreatedAt INTEGER NOT NULL
      )
    ''');

    // -------------------- 创建schedules表 --------------------
    // 艾宾浩斯调度表，记录每个学习内容的复习计划
    await db.execute('''
      CREATE TABLE $tableSchedules (
        $colId TEXT PRIMARY KEY,
        $colContentId TEXT NOT NULL,
        $colNextReviewDate INTEGER NOT NULL,
        $colIntervalDays INTEGER NOT NULL DEFAULT 0,
        $colErrorCount INTEGER NOT NULL DEFAULT 0,
        $colConsecutiveCorrect INTEGER NOT NULL DEFAULT 0,
        $colStatus TEXT NOT NULL DEFAULT 'new_word',
        $colLastResult TEXT,
        $colCreatedAt INTEGER NOT NULL,
        $colUpdatedAt INTEGER NOT NULL,
        FOREIGN KEY ($colContentId) REFERENCES $tableContents($colId)
      )
    ''');

    // -------------------- 创建poem_errors表 --------------------
    // 古诗词错字明细表，记录孩子在默写古诗词时写错的字
    await db.execute('''
      CREATE TABLE $tablePoemErrors (
        $colId TEXT PRIMARY KEY,
        $colPoemId TEXT NOT NULL,
        $colCharIndex INTEGER NOT NULL,
        $colStandardChar TEXT NOT NULL,
        $colWrongChar TEXT,
        $colErrorDate INTEGER NOT NULL,
        $colReviewCount INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY ($colPoemId) REFERENCES $tableContents($colId)
      )
    ''');

    // -------------------- 创建check_ins表 --------------------
    // 打卡记录表，记录每天的学习情况
    await db.execute('''
      CREATE TABLE $tableCheckIns (
        $colId TEXT PRIMARY KEY,
        $colDate INTEGER NOT NULL UNIQUE,
        $colTaskCount INTEGER NOT NULL DEFAULT 0,
        $colCorrectCount INTEGER NOT NULL DEFAULT 0,
        $colWrongCount INTEGER NOT NULL DEFAULT 0,
        $colDurationMinutes INTEGER
      )
    ''');

    // -------------------- 创建math_recordings表 --------------------
    // 数学问答录音表，记录孩子回答数学问题的录音文件
    await db.execute('''
      CREATE TABLE $tableMathRecordings (
        $colId TEXT PRIMARY KEY,
        $colContentId TEXT NOT NULL,
        $colFilePath TEXT NOT NULL,
        $colRecordedAt INTEGER NOT NULL,
        $colParentRating TEXT,
        $colRatedAt INTEGER,
        FOREIGN KEY ($colContentId) REFERENCES $tableContents($colId)
      )
    ''');

    // ==================== 创建索引（优化查询性能） ====================

    // -------------------- contents表索引 --------------------
    // 按类型索引（快速筛选特定类型的内容）
    await db.execute('''
      CREATE INDEX idx_contents_type ON $tableContents($colType)
    ''');
    // 按父内容ID索引（快速查找关联内容，如错字关联原诗）
    await db.execute('''
      CREATE INDEX idx_contents_parent ON $tableContents($colParentId)
    ''');
    // 按内容+来源联合索引（快速判断重复内容）
    await db.execute('''
      CREATE INDEX idx_contents_dup ON $tableContents($colContent, $colSource)
    ''');

    // -------------------- schedules表索引 --------------------
    // 按内容ID索引（快速查找某个内容的调度记录）
    await db.execute('''
      CREATE INDEX idx_schedules_content ON $tableSchedules($colContentId)
    ''');
    // 按下次复习日期索引（快速查找到期复习项）
    await db.execute('''
      CREATE INDEX idx_schedules_due ON $tableSchedules($colNextReviewDate)
    ''');
    // 按状态索引（快速筛选特定状态的学习项）
    await db.execute('''
      CREATE INDEX idx_schedules_status ON $tableSchedules($colStatus)
    ''');
    // 按状态+错误次数联合索引（快速查找困难词）
    await db.execute('''
      CREATE INDEX idx_schedules_diff ON $tableSchedules($colStatus, $colErrorCount)
    ''');

    // -------------------- poem_errors表索引 --------------------
    // 按诗词ID索引（快速查找某首诗的所有错字记录）
    await db.execute('''
      CREATE INDEX idx_poem_errors_poem ON $tablePoemErrors($colPoemId)
    ''');

    // -------------------- math_recordings表索引 --------------------
    // 按内容ID索引（快速查找某道题的所有录音记录）
    await db.execute('''
      CREATE INDEX idx_math_recordings_content ON $tableMathRecordings($colContentId)
    ''');
    // 按录音时间索引（快速按时间排序和清理旧记录）
    await db.execute('''
      CREATE INDEX idx_math_recordings_date ON $tableMathRecordings($colRecordedAt)
    ''');
  }

  /// 数据库版本升级时调用
  /// 当数据库版本号增加时执行升级操作
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 当前为版本1，无需升级逻辑
    // 后续版本升级时在此添加迁移脚本
    // 例如：
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE contents ADD COLUMN new_column TEXT');
    // }
  }

  // ==================== 日期处理辅助函数 ====================

  /// 将DateTime转换为毫秒时间戳
  int _dateToMillis(DateTime date) => date.millisecondsSinceEpoch;

  /// 将毫秒时间戳转换为DateTime
  DateTime _millisToDateTime(int millis) => DateTime.fromMillisecondsSinceEpoch(millis);

  /// 获取仅含年月日的DateTime（时间为00:00:00）
  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  /// 获取仅含年月日的毫秒时间戳（用于日期比较）
  int _dateOnlyMillis(DateTime date) => _dateOnly(date).millisecondsSinceEpoch;

  // ==================== contents表CRUD操作 ====================

  /// 插入一条学习内容记录
  /// 返回插入的行ID（对于TEXT主键，实际是内部行ID）
  Future<int> insertContent(Content content) async {
    final db = await database;
    return await db.insert(
      tableContents,
      content.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 批量插入学习内容记录（使用事务提高性能）
  /// 返回成功插入的记录数
  Future<int> insertContentsBatch(List<Content> contents) async {
    final db = await database;
    int count = 0;
    // 使用事务保证原子性
    await db.transaction((txn) async {
      for (final content in contents) {
        await txn.insert(
          tableContents,
          content.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }
    });
    return count;
  }

  /// 获取所有学习内容记录
  /// 按创建时间升序排列
  Future<List<Content>> getAllContents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableContents,
      orderBy: '$colCreatedAt ASC',
    );
    return List.generate(maps.length, (i) => Content.fromMap(maps[i]));
  }

  /// 根据ID获取单条学习内容记录
  /// 找不到时返回null
  Future<Content?> getContentById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableContents,
      where: '$colId = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) {
      return null;
    }
    return Content.fromMap(maps.first);
  }

  /// 根据类型获取学习内容记录
  /// 例如：type='chinese_char' 获取所有汉字内容
  Future<List<Content>> getContentsByType(String type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableContents,
      where: '$colType = ?',
      whereArgs: [type],
      orderBy: '$colCreatedAt ASC',
    );
    return List.generate(maps.length, (i) => Content.fromMap(maps[i]));
  }

  /// 根据父内容ID获取关联的子内容
  /// 用于获取某首诗的所有错字内容
  Future<List<Content>> getContentsByParentId(String parentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableContents,
      where: '$colParentId = ?',
      whereArgs: [parentId],
      orderBy: '$colCreatedAt ASC',
    );
    return List.generate(maps.length, (i) => Content.fromMap(maps[i]));
  }

  /// 更新一条学习内容记录
  /// 返回受影响的行数
  Future<int> updateContent(Content content) async {
    final db = await database;
    return await db.update(
      tableContents,
      content.toMap(),
      where: '$colId = ?',
      whereArgs: [content.id],
    );
  }

  /// 根据ID删除一条学习内容记录
  /// 返回受影响的行数（关联的schedules、poem_errors、math_recordings会因外键级联删除）
  Future<int> deleteContent(String id) async {
    final db = await database;
    return await db.delete(
      tableContents,
      where: '$colId = ?',
      whereArgs: [id],
    );
  }

  /// 检查指定内容和来源的组合是否已存在
  /// 用于CSV导入时去重判断
  Future<bool> contentExists(String content, String source) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableContents,
      where: '$colContent = ? AND $colSource = ?',
      whereArgs: [content, source],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  /// 获取学习内容的总数
  Future<int> getContentCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableContents');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取指定类型的学习内容数量
  Future<int> getContentCountByType(String type) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableContents WHERE $colType = ?',
      [type],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== schedules表CRUD操作 ====================

  /// 插入一条调度记录
  Future<int> insertSchedule(Schedule schedule) async {
    final db = await database;
    return await db.insert(
      tableSchedules,
      schedule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 批量插入调度记录（使用事务）
  Future<int> insertSchedulesBatch(List<Schedule> schedules) async {
    final db = await database;
    int count = 0;
    await db.transaction((txn) async {
      for (final schedule in schedules) {
        await txn.insert(
          tableSchedules,
          schedule.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }
    });
    return count;
  }

  /// 获取所有调度记录
  Future<List<Schedule>> getAllSchedules() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableSchedules,
      orderBy: '$colCreatedAt ASC',
    );
    return List.generate(maps.length, (i) => Schedule.fromMap(maps[i]));
  }

  /// 根据内容ID获取对应的调度记录
  /// 每个内容只有一条调度记录，找不到时返回null
  Future<Schedule?> getScheduleByContentId(String contentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableSchedules,
      where: '$colContentId = ?',
      whereArgs: [contentId],
      limit: 1,
    );
    if (maps.isEmpty) {
      return null;
    }
    return Schedule.fromMap(maps.first);
  }

  /// 获取指定日期之前（含）所有到期的调度记录
  /// 用于生成每日复习任务
  Future<List<Schedule>> getDueSchedules(DateTime date) async {
    final db = await database;
    final targetDateMillis = _dateOnlyMillis(date);
    final List<Map<String, dynamic>> maps = await db.query(
      tableSchedules,
      where: '$colNextReviewDate <= ? AND $colStatus != ?',
      whereArgs: [targetDateMillis, 'mastered'],
      orderBy: '$colErrorCount DESC, $colNextReviewDate ASC',
    );
    return List.generate(maps.length, (i) => Schedule.fromMap(maps[i]));
  }

  /// 获取所有困难词（status为difficult）的调度记录
  /// 按错误次数降序排列
  Future<List<Schedule>> getDifficultSchedules() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableSchedules,
      where: '$colStatus = ?',
      whereArgs: ['difficult'],
      orderBy: '$colErrorCount DESC',
    );
    return List.generate(maps.length, (i) => Schedule.fromMap(maps[i]));
  }

  /// 获取所有新词（status为new_word）的调度记录
  Future<List<Schedule>> getNewWordSchedules() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableSchedules,
      where: '$colStatus = ?',
      whereArgs: ['new_word'],
      orderBy: '$colCreatedAt ASC',
    );
    return List.generate(maps.length, (i) => Schedule.fromMap(maps[i]));
  }

  /// 获取所有学习中（status为learning）的调度记录
  Future<List<Schedule>> getLearningSchedules() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableSchedules,
      where: '$colStatus = ?',
      whereArgs: ['learning'],
      orderBy: '$colErrorCount DESC, $colNextReviewDate ASC',
    );
    return List.generate(maps.length, (i) => Schedule.fromMap(maps[i]));
  }

  /// 获取所有已掌握（status为mastered）的调度记录
  Future<List<Schedule>> getMasteredSchedules() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableSchedules,
      where: '$colStatus = ?',
      whereArgs: ['mastered'],
      orderBy: '$colConsecutiveCorrect DESC',
    );
    return List.generate(maps.length, (i) => Schedule.fromMap(maps[i]));
  }

  /// 更新一条调度记录
  Future<int> updateSchedule(Schedule schedule) async {
    final db = await database;
    // 更新时自动设置更新时间为当前时间
    schedule.updatedAt = DateTime.now();
    return await db.update(
      tableSchedules,
      schedule.toMap(),
      where: '$colId = ?',
      whereArgs: [schedule.id],
    );
  }

  /// 批量更新调度记录（使用事务）
  Future<int> updateSchedulesBatch(List<Schedule> schedules) async {
    final db = await database;
    int count = 0;
    await db.transaction((txn) async {
      for (final schedule in schedules) {
        schedule.updatedAt = DateTime.now();
        count += await txn.update(
          tableSchedules,
          schedule.toMap(),
          where: '$colId = ?',
          whereArgs: [schedule.id],
        );
      }
    });
    return count;
  }

  /// 根据ID删除一条调度记录
  Future<int> deleteSchedule(String id) async {
    final db = await database;
    return await db.delete(
      tableSchedules,
      where: '$colId = ?',
      whereArgs: [id],
    );
  }

  /// 根据内容ID删除调度记录
  Future<int> deleteScheduleByContentId(String contentId) async {
    final db = await database;
    return await db.delete(
      tableSchedules,
      where: '$colContentId = ?',
      whereArgs: [contentId],
    );
  }

  // ==================== poem_errors表CRUD操作 ====================

  /// 插入一条古诗词错字记录
  Future<int> insertPoemError(PoemError error) async {
    final db = await database;
    return await db.insert(
      tablePoemErrors,
      error.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 批量插入错字记录（使用事务）
  Future<int> insertPoemErrorsBatch(List<PoemError> errors) async {
    final db = await database;
    int count = 0;
    await db.transaction((txn) async {
      for (final error in errors) {
        await txn.insert(
          tablePoemErrors,
          error.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }
    });
    return count;
  }

  /// 根据诗词ID获取该诗的所有错字记录
  Future<List<PoemError>> getPoemErrorsByPoemId(String poemId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tablePoemErrors,
      where: '$colPoemId = ?',
      whereArgs: [poemId],
      orderBy: '$colCharIndex ASC',
    );
    return List.generate(maps.length, (i) => PoemError.fromMap(maps[i]));
  }

  /// 根据诗词ID和字符位置获取特定的错字记录
  /// 用于查找某首诗某个特定位置是否有错字记录
  Future<PoemError?> getPoemErrorByChar(String poemId, int charIndex) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tablePoemErrors,
      where: '$colPoemId = ? AND $colCharIndex = ?',
      whereArgs: [poemId, charIndex],
      limit: 1,
    );
    if (maps.isEmpty) {
      return null;
    }
    return PoemError.fromMap(maps.first);
  }

  /// 更新一条错字记录
  Future<int> updatePoemError(PoemError error) async {
    final db = await database;
    return await db.update(
      tablePoemErrors,
      error.toMap(),
      where: '$colId = ?',
      whereArgs: [error.id],
    );
  }

  /// 根据ID删除一条错字记录
  Future<int> deletePoemError(String id) async {
    final db = await database;
    return await db.delete(
      tablePoemErrors,
      where: '$colId = ?',
      whereArgs: [id],
    );
  }

  /// 根据诗词ID删除该诗的所有错字记录
  Future<int> deletePoemErrorsByPoemId(String poemId) async {
    final db = await database;
    return await db.delete(
      tablePoemErrors,
      where: '$colPoemId = ?',
      whereArgs: [poemId],
    );
  }

  // ==================== check_ins表CRUD操作 ====================

  /// 插入一条打卡记录
  Future<int> insertCheckIn(CheckIn checkIn) async {
    final db = await database;
    return await db.insert(
      tableCheckIns,
      checkIn.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 根据日期获取打卡记录
  /// 日期参数的时间部分会被忽略，只比较年月日
  Future<CheckIn?> getCheckInByDate(DateTime date) async {
    final db = await database;
    final dateMillis = _dateOnlyMillis(date);
    final List<Map<String, dynamic>> maps = await db.query(
      tableCheckIns,
      where: '$colDate = ?',
      whereArgs: [dateMillis],
      limit: 1,
    );
    if (maps.isEmpty) {
      return null;
    }
    return CheckIn.fromMap(maps.first);
  }

  /// 获取今天的打卡记录
  Future<CheckIn?> getTodayCheckIn() async {
    return await getCheckInByDate(DateTime.now());
  }

  /// 获取最近N天的打卡记录
  /// 返回按日期降序排列的列表（最近的在前面）
  Future<List<CheckIn>> getRecentCheckIns(int days) async {
    final db = await database;
    final now = DateTime.now();
    // 计算N天前的日期
    final startDate = _dateOnlyMillis(now.subtract(Duration(days: days - 1)));
    final List<Map<String, dynamic>> maps = await db.query(
      tableCheckIns,
      where: '$colDate >= ?',
      whereArgs: [startDate],
      orderBy: '$colDate DESC',
    );
    return List.generate(maps.length, (i) => CheckIn.fromMap(maps[i]));
  }

  /// 更新一条打卡记录
  Future<int> updateCheckIn(CheckIn checkIn) async {
    final db = await database;
    return await db.update(
      tableCheckIns,
      checkIn.toMap(),
      where: '$colId = ?',
      whereArgs: [checkIn.id],
    );
  }

  /// 删除指定日期的打卡记录
  Future<int> deleteCheckInByDate(DateTime date) async {
    final db = await database;
    final dateMillis = _dateOnlyMillis(date);
    return await db.delete(
      tableCheckIns,
      where: '$colDate = ?',
      whereArgs: [dateMillis],
    );
  }

  // ==================== math_recordings表CRUD操作 ====================

  /// 插入一条数学录音记录
  Future<int> insertMathRecording(MathRecording recording) async {
    final db = await database;
    return await db.insert(
      tableMathRecordings,
      recording.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取所有未评分的录音记录
  /// 未评分指parent_rating为null的记录
  Future<List<MathRecording>> getUnratedRecordings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableMathRecordings,
      where: '$colParentRating IS NULL',
      orderBy: '$colRecordedAt DESC',
    );
    return List.generate(maps.length, (i) => MathRecording.fromMap(maps[i]));
  }

  /// 根据内容ID获取该题的所有录音记录
  Future<List<MathRecording>> getRecordingsByContentId(String contentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableMathRecordings,
      where: '$colContentId = ?',
      whereArgs: [contentId],
      orderBy: '$colRecordedAt DESC',
    );
    return List.generate(maps.length, (i) => MathRecording.fromMap(maps[i]));
  }

  /// 更新一条录音记录（主要用于评分）
  Future<int> updateMathRecording(MathRecording recording) async {
    final db = await database;
    return await db.update(
      tableMathRecordings,
      recording.toMap(),
      where: '$colId = ?',
      whereArgs: [recording.id],
    );
  }

  /// 根据ID删除一条录音记录
  Future<int> deleteMathRecording(String id) async {
    final db = await database;
    return await db.delete(
      tableMathRecordings,
      where: '$colId = ?',
      whereArgs: [id],
    );
  }

  /// 根据内容ID删除该题的所有录音记录
  Future<int> deleteRecordingsByContentId(String contentId) async {
    final db = await database;
    return await db.delete(
      tableMathRecordings,
      where: '$colContentId = ?',
      whereArgs: [contentId],
    );
  }

  /// 清理指定天数之前的旧录音记录
  /// keepDays：保留最近多少天的记录
  /// 返回删除的记录数
  Future<int> cleanupOldRecordings(int keepDays) async {
    final db = await database;
    // 计算截止日期
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    final cutoffMillis = cutoffDate.millisecondsSinceEpoch;
    return await db.delete(
      tableMathRecordings,
      where: '$colRecordedAt < ?',
      whereArgs: [cutoffMillis],
    );
  }

  // ==================== 统计查询方法 ====================

  /// 获取今日统计数据
  /// 返回包含taskCount, correctCount, wrongCount, accuracyRate的Map
  Future<Map<String, dynamic>> getTodayStats() async {
    final db = await database;
    final todayMillis = _dateOnlyMillis(DateTime.now());

    // 查询今日打卡记录
    final checkInResult = await db.query(
      tableCheckIns,
      where: '$colDate = ?',
      whereArgs: [todayMillis],
      limit: 1,
    );

    if (checkInResult.isNotEmpty) {
      final checkIn = CheckIn.fromMap(checkInResult.first);
      final total = checkIn.correctCount + checkIn.wrongCount;
      final accuracy = total > 0
          ? (checkIn.correctCount / total * 100).toStringAsFixed(1)
          : '0.0';
      return {
        'taskCount': checkIn.taskCount,
        'correctCount': checkIn.correctCount,
        'wrongCount': checkIn.wrongCount,
        'accuracyRate': accuracy,
        'durationMinutes': checkIn.durationMinutes ?? 0,
      };
    }

    // 没有今日打卡记录时返回零值
    return {
      'taskCount': 0,
      'correctCount': 0,
      'wrongCount': 0,
      'accuracyRate': '0.0',
      'durationMinutes': 0,
    };
  }

  /// 获取学习统计信息
  /// 返回总内容数、已掌握数、困难词数、新词数、学习中天数等
  Future<Map<String, dynamic>> getLearningStats() async {
    final db = await database;

    // 总内容数
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableContents',
    );
    final totalContent = Sqflite.firstIntValue(totalResult) ?? 0;

    // 已掌握数
    final masteredResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM $tableSchedules WHERE $colStatus = ?",
      ['mastered'],
    );
    final masteredCount = Sqflite.firstIntValue(masteredResult) ?? 0;

    // 困难词数
    final difficultResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM $tableSchedules WHERE $colStatus = ?",
      ['difficult'],
    );
    final difficultCount = Sqflite.firstIntValue(difficultResult) ?? 0;

    // 新词数
    final newWordResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM $tableSchedules WHERE $colStatus = ?",
      ['new_word'],
    );
    final newWordCount = Sqflite.firstIntValue(newWordResult) ?? 0;

    // 学习中数
    final learningResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM $tableSchedules WHERE $colStatus = ?",
      ['learning'],
    );
    final learningCount = Sqflite.firstIntValue(learningResult) ?? 0;

    // 总打卡天数
    final checkInResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableCheckIns',
    );
    final totalCheckInDays = Sqflite.firstIntValue(checkInResult) ?? 0;

    // 连续打卡天数
    final consecutiveDays = await _getConsecutiveCheckInDays(db);

    // 总错误次数
    final totalErrorsResult = await db.rawQuery(
      'SELECT SUM($colErrorCount) as total FROM $tableSchedules',
    );
    final totalErrors =
        (totalErrorsResult.first['total'] as num?)?.toInt() ?? 0;

    return {
      'totalContent': totalContent,
      'masteredCount': masteredCount,
      'difficultCount': difficultCount,
      'newWordCount': newWordCount,
      'learningCount': learningCount,
      'totalCheckInDays': totalCheckInDays,
      'consecutiveDays': consecutiveDays,
      'totalErrors': totalErrors,
    };
  }

  /// 计算连续打卡天数
  /// 从今天往前数，直到找到中断的日期
  Future<int> _getConsecutiveCheckInDays(Database db) async {
    int consecutiveDays = 0;
    DateTime currentDate = DateTime.now();

    while (true) {
      final dateMillis = _dateOnlyMillis(currentDate);
      final result = await db.query(
        tableCheckIns,
        where: '$colDate = ?',
        whereArgs: [dateMillis],
        limit: 1,
      );
      if (result.isEmpty) {
        // 找到中断日期，退出循环
        break;
      }
      consecutiveDays++;
      // 往前推一天
      currentDate = currentDate.subtract(const Duration(days: 1));

      // 防止无限循环（最多查365天）
      if (consecutiveDays >= 365) {
        break;
      }
    }

    return consecutiveDays;
  }

  // ==================== 数据清理方法 ====================

  /// 清除所有数据
  /// 删除所有表中的数据，保留表结构
  /// 用于重置应用数据或注销账号
  Future<void> clearAllData() async {
    final db = await database;
    // 使用事务确保原子性
    await db.transaction((txn) async {
      // 按外键依赖顺序删除（先删子表，再删父表）
      await txn.delete(tableMathRecordings);
      await txn.delete(tablePoemErrors);
      await txn.delete(tableSchedules);
      await txn.delete(tableCheckIns);
      await txn.delete(tableContents);
    });
  }

  /// 关闭数据库连接
  /// 在应用退出或不再需要数据库时调用
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // ==================== 事务包装方法 ====================

  /// 在事务中执行一组操作
  /// callback：在事务上下文中执行的回调函数
  Future<T> runInTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  // ==================== 联合查询方法 ====================

  /// 获取困难词及其关联的内容信息
  /// 返回包含Content和Schedule的组合数据
  Future<List<Map<String, dynamic>>> getDifficultWordsWithContent() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT c.*, s.$colIntervalDays, s.$colErrorCount, s.$colConsecutiveCorrect,
             s.$colStatus, s.$colNextReviewDate, s.$colLastResult
      FROM $tableContents c
      INNER JOIN $tableSchedules s ON c.$colId = s.$colContentId
      WHERE s.$colStatus = ?
      ORDER BY s.$colErrorCount DESC
    ''', ['difficult']);
    return result;
  }

  /// 获取到期复习项及其关联的内容信息
  Future<List<Map<String, dynamic>>> getDueItemsWithContent(DateTime date) async {
    final db = await database;
    final targetDateMillis = _dateOnlyMillis(date);
    final result = await db.rawQuery('''
      SELECT c.*, s.$colIntervalDays, s.$colErrorCount, s.$colConsecutiveCorrect,
             s.$colStatus, s.$colNextReviewDate, s.$colLastResult
      FROM $tableContents c
      INNER JOIN $tableSchedules s ON c.$colId = s.$colContentId
      WHERE s.$colNextReviewDate <= ? AND s.$colStatus != ?
      ORDER BY s.$colErrorCount DESC, s.$colNextReviewDate ASC
    ''', [targetDateMillis, 'mastered']);
    return result;
  }

  /// 获取指定类型的内容数量统计
  Future<Map<String, int>> getContentTypeStats() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT $colType, COUNT(*) as count
      FROM $tableContents
      GROUP BY $colType
    ''');
    final Map<String, int> stats = {};
    for (final row in result) {
      final type = row[colType] as String;
      final count = (row['count'] as num).toInt();
      stats[type] = count;
    }
    return stats;
  }

  /// 获取最近N天的每日统计
  /// 返回日期字符串到统计数据的映射
  Future<Map<String, Map<String, dynamic>>> getDailyStats(int days) async {
    final db = await database;
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days - 1));
    final startMillis = _dateOnlyMillis(startDate);

    final result = await db.query(
      tableCheckIns,
      where: '$colDate >= ?',
      whereArgs: [startMillis],
      orderBy: '$colDate ASC',
    );

    final Map<String, Map<String, dynamic>> dailyStats = {};
    for (final row in result) {
      final checkIn = CheckIn.fromMap(row);
      final dateKey =
          '${checkIn.date.year}-${checkIn.date.month.toString().padLeft(2, '0')}-${checkIn.date.day.toString().padLeft(2, '0')}';
      final total = checkIn.correctCount + checkIn.wrongCount;
      final accuracy = total > 0 ? checkIn.correctCount / total * 100 : 0.0;

      dailyStats[dateKey] = {
        'taskCount': checkIn.taskCount,
        'correctCount': checkIn.correctCount,
        'wrongCount': checkIn.wrongCount,
        'accuracyRate': accuracy.toStringAsFixed(1),
        'durationMinutes': checkIn.durationMinutes ?? 0,
      };
    }

    return dailyStats;
  }

  // ==================== 便捷工具方法 ====================

  /// 判断今日是否已打卡
  Future<bool> isTodayCheckedIn() async {
    final checkIn = await getTodayCheckIn();
    return checkIn != null;
  }

  /// 增加今日打卡的统计数据
  /// 如果今日没有打卡记录，则自动创建
  Future<void> incrementTodayStats(int correct, int wrong, {int? durationMinutes}) async {
    final db = await database;
    final todayMillis = _dateOnlyMillis(DateTime.now());

    await db.transaction((txn) async {
      // 查询今日打卡记录
      final result = await txn.query(
        tableCheckIns,
        where: '$colDate = ?',
        whereArgs: [todayMillis],
        limit: 1,
      );

      if (result.isEmpty) {
        // 创建新的打卡记录
        final newCheckIn = CheckIn(
          date: _dateOnly(DateTime.now()),
          taskCount: correct + wrong,
          correctCount: correct,
          wrongCount: wrong,
          durationMinutes: durationMinutes,
        );
        await txn.insert(tableCheckIns, newCheckIn.toMap());
      } else {
        // 更新已有记录
        final checkIn = CheckIn.fromMap(result.first);
        checkIn.correctCount += correct;
        checkIn.wrongCount += wrong;
        checkIn.taskCount += correct + wrong;
        if (durationMinutes != null) {
          checkIn.durationMinutes =
              (checkIn.durationMinutes ?? 0) + durationMinutes;
        }
        await txn.update(
          tableCheckIns,
          checkIn.toMap(),
          where: '$colDate = ?',
          whereArgs: [todayMillis],
        );
      }
    });
  }

  /// 获取指定诗词的所有错字位置列表
  /// 返回字符位置索引的列表
  Future<List<int>> getPoemErrorCharIndices(String poemId) async {
    final db = await database;
    final result = await db.query(
      tablePoemErrors,
      columns: [colCharIndex],
      where: '$colPoemId = ?',
      whereArgs: [poemId],
      orderBy: '$colCharIndex ASC',
    );
    return result.map((row) => row[colCharIndex] as int).toList();
  }

  /// 判断某首诗的某个字符位置是否有错字记录
  Future<bool> hasPoemErrorAtChar(String poemId, int charIndex) async {
    final error = await getPoemErrorByChar(poemId, charIndex);
    return error != null;
  }

  /// 获取已评分的录音记录
  Future<List<MathRecording>> getRatedRecordings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableMathRecordings,
      where: '$colParentRating IS NOT NULL',
      orderBy: '$colRatedAt DESC',
    );
    return List.generate(maps.length, (i) => MathRecording.fromMap(maps[i]));
  }

  /// 根据评分获取录音记录
  Future<List<MathRecording>> getRecordingsByRating(String rating) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableMathRecordings,
      where: '$colParentRating = ?',
      whereArgs: [rating],
      orderBy: '$colRecordedAt DESC',
    );
    return List.generate(maps.length, (i) => MathRecording.fromMap(maps[i]));
  }

  /// 获取指定时间段内的打卡记录
  Future<List<CheckIn>> getCheckInsByDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final startMillis = _dateOnlyMillis(start);
    final endMillis = _dateOnlyMillis(end);
    final List<Map<String, dynamic>> maps = await db.query(
      tableCheckIns,
      where: '$colDate >= ? AND $colDate <= ?',
      whereArgs: [startMillis, endMillis],
      orderBy: '$colDate DESC',
    );
    return List.generate(maps.length, (i) => CheckIn.fromMap(maps[i]));
  }

  /// 获取未评分录音数量
  Future<int> getUnratedRecordingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableMathRecordings WHERE $colParentRating IS NULL',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取总录音数量
  Future<int> getTotalRecordingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableMathRecordings',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取指定诗词的错字数量
  Future<int> getPoemErrorCount(String poemId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tablePoemErrors WHERE $colPoemId = ?',
      [poemId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取调度记录总数
  Future<int> getScheduleCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableSchedules',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取今日到期任务数量
  Future<int> getTodayDueCount() async {
    final db = await database;
    final todayMillis = _dateOnlyMillis(DateTime.now());
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableSchedules WHERE $colNextReviewDate <= ? AND $colStatus != ?',
      [todayMillis, 'mastered'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
