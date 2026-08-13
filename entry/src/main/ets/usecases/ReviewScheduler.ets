import { Mistake } from '../models/Mistake';
import { MistakeStatus, AnswerType, GradingMethod } from '../models/Enums';

const INTERVALS_DAYS: number[] = [1, 3, 7, 15, 30];
const MS_PER_DAY: number = 24 * 60 * 60 * 1000;

export class ReviewScheduler {
  static scheduleNextReview(mistake: Mistake, correct: boolean): void {
    let idx = mistake.intervalIndex;
    if (correct) {
      idx = Math.min(idx + 1, INTERVALS_DAYS.length - 1);
    } else {
      idx = 0;
    }
    mistake.intervalIndex = idx;
    mistake.nextReviewDate = Date.now() + INTERVALS_DAYS[idx] * MS_PER_DAY;
    if (correct) {
      mistake.status = MistakeStatus.REVIEWING;
    } else {
      mistake.status = MistakeStatus.UNMASTERED;
    }
  }

  static getIntervalsDays(): number[] {
    return INTERVALS_DAYS;
  }

  static getNextIntervalDays(index: number): number {
    if (index >= 0 && index < INTERVALS_DAYS.length) {
      return INTERVALS_DAYS[index];
    }
    return INTERVALS_DAYS[0];
  }
}
