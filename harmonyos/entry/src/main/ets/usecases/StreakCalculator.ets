/**
 * 连续学习天数计算（T033/FR-016）：
 * - 活动日 = 当日有任意有效学习行为（录入错题 / 完成复习），按本地日历日去重；
 * - streak 从今天（今天未学习则从昨天，保留至当日结束）向前连续计数；
 * - 连击积分按天发放且不重复（shouldAwardToday 当日去重判断）。
 */
export class StreakCalculator {
  /** 计算连续学习天数（activeDays 为 ISO 日期串 YYYY-MM-DD 集合，顺序不限）。 */
  static compute(activeDays: string[]): number {
    if (activeDays.length === 0) {
      return 0;
    }
    const set: Set<string> = new Set<string>(activeDays);
    let cursor: Date = new Date();
    if (!set.has(StreakCalculator.toIsoDate(cursor))) {
      // 今天还没有学习行为：允许从昨天续算（当日结束时 streak 才断）
      cursor = new Date(cursor.getTime() - 24 * 60 * 60 * 1000);
      if (!set.has(StreakCalculator.toIsoDate(cursor))) {
        return 0;
      }
    }
    let streak: number = 0;
    while (set.has(StreakCalculator.toIsoDate(cursor))) {
      streak++;
      cursor = new Date(cursor.getTime() - 24 * 60 * 60 * 1000);
    }
    return streak;
  }

  /** 当日是否应发放连击积分：今天有学习行为 && 今日未发过 STREAK 分。 */
  static shouldAwardToday(activeDays: string[], lastStreakAwardDay: string): boolean {
    if (activeDays.length === 0) {
      return false;
    }
    const todayIso: string = StreakCalculator.todayIso();
    const set: Set<string> = new Set<string>(activeDays);
    return set.has(todayIso) && lastStreakAwardDay !== todayIso;
  }

  static todayIso(): string {
    return StreakCalculator.toIsoDate(new Date());
  }

  private static toIsoDate(d: Date): string {
    const y: number = d.getFullYear();
    const m: number = d.getMonth() + 1;
    const day: number = d.getDate();
    return `${y}-${m < 10 ? '0' + m : m}-${day < 10 ? '0' + day : day}`;
  }
}
