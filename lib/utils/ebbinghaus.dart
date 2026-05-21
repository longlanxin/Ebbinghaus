// lib/utils/ebbinghaus.dart
// 艾宾浩斯遗忘曲线 - 纯函数间隔计算工具
// 所有函数均为纯函数，无副作用，便于单元测试

import 'constants.dart';

// ============================================================
// 艾宾浩斯间隔核心计算函数
// ============================================================

/// 根据当前间隔索引获取下一个间隔天数
///
/// [currentIndex] - 当前在间隔序列中的索引位置（从0开始）
/// 返回下一个间隔天数
///
/// 例如：
/// - currentIndex = 0 -> 返回 1（第2次复习，隔天）
/// - currentIndex = 3 -> 返回 7（第5次复习，间隔7天）
/// - currentIndex = 6 -> 返回 30（第7次+复习，间隔30天）
/// - currentIndex >= 7 -> 返回 30（超过最大索引，保持30天）
int getNextInterval(int currentIndex) {
  // 索引小于0时，从头开始
  if (currentIndex < 0) {
    return kEbbinghausIntervals[0];
  }

  // 索引在有效范围内，返回下一个间隔
  if (currentIndex < kEbbinghausIntervals.length - 1) {
    return kEbbinghausIntervals[currentIndex + 1];
  }

  // 索引已超过最大索引，使用最后一个间隔值（30天）
  return kEbbinghausIntervals[kMaxIntervalIndex];
}

/// 根据索引直接获取对应的间隔天数
///
/// [index] - 间隔序列索引（从0开始）
/// 返回对应的间隔天数
///
/// 例如：
/// - index = 0 -> 返回 1
/// - index = 3 -> 返回 4
/// - index = 6 -> 返回 30
/// - index >= 7 -> 返回 30
int getIntervalForIndex(int index) {
  if (index < 0) {
    return kEbbinghausIntervals[0];
  }
  if (index >= kEbbinghausIntervals.length) {
    return kEbbinghausIntervals[kMaxIntervalIndex];
  }
  return kEbbinghausIntervals[index];
}

/// 计算下次复习日期
///
/// [currentDate] - 当前日期（通常为今天）
/// [intervalDays] - 间隔天数
/// 返回下次应该复习的日期（时间为00:00:00）
///
/// 例如：
/// - currentDate = 2024-01-01, intervalDays = 1 -> 2024-01-02
/// - currentDate = 2024-01-01, intervalDays = 7 -> 2024-01-08
DateTime calculateNextReviewDate(DateTime currentDate, int intervalDays) {
  // 将日期标准化为当天的00:00:00，避免时间部分影响比较
  final normalizedDate = DateTime(currentDate.year, currentDate.month, currentDate.day);

  // 加上间隔天数
  return normalizedDate.add(Duration(days: intervalDays));
}

/// 回答错误时的间隔缩短逻辑
///
/// [intervalDays] - 当前间隔天数
/// 返回缩短后的间隔天数（至少为1天）
///
/// 规则：间隔缩短50%（向下取整），但最少保持1天
/// 例如：
/// - intervalDays = 15 -> 返回 7 (15 ~/ 2)
/// - intervalDays = 4  -> 返回 2 (4 ~/ 2)
/// - intervalDays = 1  -> 返回 1 (不能小于1)
/// - intervalDays = 0  -> 返回 1 (新词错误，设置为明天复习)
int adjustIntervalOnWrong(int intervalDays) {
  // 缩短50%，向下取整，至少1天
  final adjusted = intervalDays ~/ 2;
  return adjusted > 0 ? adjusted : 1;
}

/// 回答正确时的间隔推进逻辑
///
/// [currentIndex] - 当前间隔在艾宾浩斯序列中的索引
/// 返回推进后的下一个间隔天数
///
/// 规则：按艾宾浩斯序列顺序推进
/// 例如：
/// - currentIndex = 0 -> 返回 1（第2次复习间隔）
/// - currentIndex = 2 -> 返回 4（第4次复习间隔）
/// - currentIndex = 5 -> 返回 30（第7次复习间隔）
int adjustIntervalOnCorrect(int currentIndex) {
  return getNextInterval(currentIndex);
}

/// 根据连续正确次数获取当前应该使用的间隔索引
///
/// [consecutiveCorrect] - 连续正确次数
/// 返回间隔序列中的索引位置
///
/// 连续正确次数对应间隔索引：
/// - 0次正确（新词）-> 索引0（间隔1天）
/// - 1次正确 -> 索引1（间隔1天）
/// - 2次正确 -> 索引2（间隔2天）
/// - 3次正确 -> 索引3（间隔4天）
/// - 4次正确 -> 索引4（间隔7天）
/// - 5次正确（已掌握）-> 索引5（间隔15天）
int getIntervalIndexForConsecutiveCorrect(int consecutiveCorrect) {
  if (consecutiveCorrect <= 0) {
    return 0;
  }
  if (consecutiveCorrect >= kEbbinghausIntervals.length) {
    return kMaxIntervalIndex;
  }
  return consecutiveCorrect;
}

/// 判断一个复习日期是否已经到期（小于等于今天）
///
/// [nextReviewDate] - 下次复习日期
/// [today] - 今天的日期（可选，默认为今天）
/// 返回 true 表示已经到期需要复习
bool isReviewDue(DateTime nextReviewDate, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final normalizedToday = DateTime(now.year, now.month, now.day);
  final normalizedReviewDate = DateTime(
    nextReviewDate.year,
    nextReviewDate.month,
    nextReviewDate.day,
  );
  return normalizedReviewDate.isBefore(normalizedToday) ||
      normalizedReviewDate.isAtSameMomentAs(normalizedToday);
}

/// 获取艾宾浩斯序列中下一个应该使用的间隔天数（基于当前间隔值）
///
/// [currentIntervalDays] - 当前使用的间隔天数
/// 返回下一个应该使用的间隔天数
///
/// 例如：
/// - currentIntervalDays = 1 -> 返回 2（序列中的下一个）
/// - currentIntervalDays = 7 -> 返回 15
/// - currentIntervalDays = 30 -> 返回 30（保持最大）
int advanceInterval(int currentIntervalDays) {
  // 找到当前间隔在序列中的位置
  final index = kEbbinghausIntervals.indexOf(currentIntervalDays);

  if (index == -1) {
    // 当前间隔不在标准序列中（可能是错误缩短后的值）
    // 找到最接近但不大于当前值的标准间隔，然后推进
    int closestIndex = 0;
    for (int i = 0; i < kEbbinghausIntervals.length; i++) {
      if (kEbbinghausIntervals[i] <= currentIntervalDays) {
        closestIndex = i;
      } else {
        break;
      }
    }
    return getNextInterval(closestIndex);
  }

  // 在标准序列中，直接推进到下一个
  return getNextInterval(index);
}

/// 计算两个日期之间相差的天数（忽略时间部分）
///
/// [date1] - 第一个日期
/// [date2] - 第二个日期
/// 返回两个日期之间相差的天数（可能为负数）
int daysBetween(DateTime date1, DateTime date2) {
  final d1 = DateTime(date1.year, date1.month, date1.day);
  final d2 = DateTime(date2.year, date2.month, date2.day);
  return d2.difference(d1).inDays;
}
