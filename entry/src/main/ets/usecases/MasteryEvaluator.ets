import { Mistake } from '../models/Mistake';
import { ReviewLog } from '../models/ReviewLog';
import { MistakeStatus, GradingMethod } from '../models/Enums';

const MASTERY_MIN_CONSECUTIVE_CORRECT: number = 2;
const MASTERY_SPEED_RATIO: number = 0.6;
const MIN_DISTINCT_CALENDAR_DAYS: number = 2;
const DEFAULT_BASELINE_DURATION_SECONDS: number = 60;

export class MasteryEvaluator {
  static evaluateMastery(mistake: Mistake, reviewLogs: ReviewLog[]): MistakeStatus {
    const sorted: ReviewLog[] = reviewLogs.slice().sort((a: ReviewLog, b: ReviewLog) => b.reviewTime - a.reviewTime);
    let requiredN: number = MASTERY_MIN_CONSECUTIVE_CORRECT;
    if (sorted.length > 0 && sorted[0].gradingMethod === GradingMethod.SUBJECTIVE_SELFREPORT) {
      requiredN = requiredN + 1;
    }

    if (sorted.length < requiredN) {
      return MistakeStatus.UNMASTERED;
    }

    const recent: ReviewLog[] = sorted.slice(0, requiredN);

    const allCorrect: boolean = recent.every((log: ReviewLog) => log.correct);
    if (!allCorrect) {
      return MistakeStatus.UNMASTERED;
    }

    const daySet: Set<number> = new Set();
    for (const log of recent) {
      const d = new Date(log.reviewTime);
      const key = d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate();
      daySet.add(key);
    }
    if (daySet.size < Math.min(MIN_DISTINCT_CALENDAR_DAYS, requiredN)) {
      return MistakeStatus.UNMASTERED;
    }

    const baseline: number = mistake.firstReviewDuration > 0 ? mistake.firstReviewDuration : DEFAULT_BASELINE_DURATION_SECONDS;
    const threshold: number = baseline * MASTERY_SPEED_RATIO;
    const withinThreshold: boolean = recent.every((log: ReviewLog) => log.durationSeconds <= threshold);
    if (!withinThreshold) {
      return MistakeStatus.UNMASTERED;
    }

    return MistakeStatus.MASTERED;
  }

  static resetMastery(mistake: Mistake): void {
    mistake.status = MistakeStatus.REVIEWING;
    mistake.intervalIndex = 0;
    mistake.nextReviewDate = Date.now() + 24 * 60 * 60 * 1000;
  }
}
