import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { Mistake } from '../main/ets/models/Mistake';
import { ReviewLog } from '../main/ets/models/ReviewLog';
import { MistakeStatus, AnswerType, GradingMethod, InputMethod, Subject, ErrorType, PointsActionType } from '../main/ets/models/Enums';
import { ReviewScheduler } from '../main/ets/usecases/ReviewScheduler';
import { MasteryEvaluator } from '../main/ets/usecases/MasteryEvaluator';
import { PointsCalculator } from '../main/ets/usecases/PointsCalculator';
import { SubjectDetector } from '../main/ets/usecases/SubjectDetector';

export default function coreAlgorithmTest() {
  describe('ReviewScheduler', () => {
    it('scheduleNextReview_correct_advances_interval', 0, () => {
      const mistake = new Mistake();
      mistake.intervalIndex = 0;
      mistake.status = MistakeStatus.UNMASTERED;
      ReviewScheduler.scheduleNextReview(mistake, true);
      expect(mistake.intervalIndex).assertEqual(1);
      expect(mistake.status).assertEqual(MistakeStatus.REVIEWING);
    });

    it('scheduleNextReview_wrong_resets_interval', 0, () => {
      const mistake = new Mistake();
      mistake.intervalIndex = 3;
      mistake.status = MistakeStatus.REVIEWING;
      ReviewScheduler.scheduleNextReview(mistake, false);
      expect(mistake.intervalIndex).assertEqual(0);
      expect(mistake.status).assertEqual(MistakeStatus.UNMASTERED);
    });

    it('scheduleNextReview_correct_at_max_stays_at_max', 0, () => {
      const mistake = new Mistake();
      mistake.intervalIndex = 4;
      mistake.status = MistakeStatus.REVIEWING;
      ReviewScheduler.scheduleNextReview(mistake, true);
      expect(mistake.intervalIndex).assertEqual(4);
    });

    it('getIntervalsDays_returns_5_intervals', 0, () => {
      const intervals = ReviewScheduler.getIntervalsDays();
      expect(intervals.length).assertEqual(5);
      expect(intervals[0]).assertEqual(1);
      expect(intervals[4]).assertEqual(30);
    });
  });

  describe('MasteryEvaluator', () => {
    it('evaluateMastery_insufficient_logs_returns_unmastered', 0, () => {
      const mistake = new Mistake();
      mistake.firstReviewDuration = 60;
      const logs: ReviewLog[] = [];
      const result = MasteryEvaluator.evaluateMastery(mistake, logs);
      expect(result).assertEqual(MistakeStatus.UNMASTERED);
    });

    it('evaluateMastery_all_correct_distinct_days_fast_returns_mastered', 0, () => {
      const mistake = new Mistake();
      mistake.firstReviewDuration = 60;
      const log1 = ReviewLog.create('1', 'm1', GradingMethod.OBJECTIVE_AUTO, InputMethod.SELECT, true, 30, 0);
      log1.reviewTime = new Date(2026, 0, 1).getTime();
      const log2 = ReviewLog.create('2', 'm1', GradingMethod.OBJECTIVE_AUTO, InputMethod.SELECT, true, 25, 0);
      log2.reviewTime = new Date(2026, 0, 2).getTime();
      const result = MasteryEvaluator.evaluateMastery(mistake, [log1, log2]);
      expect(result).assertEqual(MistakeStatus.MASTERED);
    });

    it('evaluateMastery_wrong_answer_returns_unmastered', 0, () => {
      const mistake = new Mistake();
      mistake.firstReviewDuration = 60;
      const log1 = ReviewLog.create('1', 'm1', GradingMethod.OBJECTIVE_AUTO, InputMethod.SELECT, true, 30, 0);
      log1.reviewTime = 200000;
      const log2 = ReviewLog.create('2', 'm1', GradingMethod.OBJECTIVE_AUTO, InputMethod.SELECT, false, 30, 0);
      log2.reviewTime = 100000;
      const result = MasteryEvaluator.evaluateMastery(mistake, [log1, log2]);
      expect(result).assertEqual(MistakeStatus.UNMASTERED);
    });

    it('evaluateMastery_subjective_requires_more_correct', 0, () => {
      const mistake = new Mistake();
      mistake.firstReviewDuration = 60;
      const log1 = ReviewLog.create('1', 'm1', GradingMethod.SUBJECTIVE_SELFREPORT, InputMethod.KEYBOARD, true, 30, 0);
      log1.reviewTime = 200000;
      const log2 = ReviewLog.create('2', 'm1', GradingMethod.SUBJECTIVE_SELFREPORT, InputMethod.KEYBOARD, true, 25, 0);
      log2.reviewTime = 100000;
      const result = MasteryEvaluator.evaluateMastery(mistake, [log1, log2]);
      expect(result).assertEqual(MistakeStatus.UNMASTERED);
    });

    it('evaluateMastery_too_slow_returns_unmastered', 0, () => {
      const mistake = new Mistake();
      mistake.firstReviewDuration = 30;
      const log1 = ReviewLog.create('1', 'm1', GradingMethod.OBJECTIVE_AUTO, InputMethod.SELECT, true, 25, 0);
      log1.reviewTime = 200000;
      const log2 = ReviewLog.create('2', 'm1', GradingMethod.OBJECTIVE_AUTO, InputMethod.SELECT, true, 30, 0);
      log2.reviewTime = 100000;
      const result = MasteryEvaluator.evaluateMastery(mistake, [log1, log2]);
      expect(result).assertEqual(MistakeStatus.UNMASTERED);
    });
  });

  describe('PointsCalculator', () => {
    it('getPointsForAction_capture_returns_5', 0, () => {
      expect(PointsCalculator.getPointsForAction(PointsActionType.CAPTURE)).assertEqual(5);
    });

    it('getPointsForAction_review_returns_10', 0, () => {
      expect(PointsCalculator.getPointsForAction(PointsActionType.ON_TIME_REVIEW)).assertEqual(10);
    });

    it('getPointsForAction_mastery_returns_20', 0, () => {
      expect(PointsCalculator.getPointsForAction(PointsActionType.MASTERY_ACHIEVED)).assertEqual(20);
    });

    it('createPointsLog_creates_correct_log', 0, () => {
      const log = PointsCalculator.createPointsLog('id1', 'stu1', PointsActionType.CAPTURE);
      expect(log.points).assertEqual(5);
      expect(log.studentId).assertEqual('stu1');
    });
  });

  describe('MistakeModel', () => {
    it('Mistake_create_sets_defaults', 0, () => {
      const m = Mistake.create('id1', 'stu1', 'img.png', 'text', Subject.MATH, ['tag1'], AnswerType.NUMERIC, '42');
      expect(m.id).assertEqual('id1');
      expect(m.subject).assertEqual(Subject.MATH);
      expect(m.answerType).assertEqual(AnswerType.NUMERIC);
      expect(m.standardAnswer).assertEqual('42');
      expect(m.status).assertEqual(MistakeStatus.UNMASTERED);
      expect(m.intervalIndex).assertEqual(0);
      expect(m.isConfirmed).assertEqual(false);
    });

    it('Mistake_default_status_is_unmastered', 0, () => {
      const m = new Mistake();
      expect(m.status).assertEqual(MistakeStatus.UNMASTERED);
    });
  });

  describe('SubjectDetector', () => {
    it('detect_math_for_formula', 0, () => {
      expect(SubjectDetector.detect('计算：3/8 + 1/4 = ?')).assertEqual(Subject.MATH);
    });
    it('detect_math_for_pure_numbers', 0, () => {
      expect(SubjectDetector.detect('25 + 17 = 42')).assertEqual(Subject.MATH);
    });
    it('detect_chinese_for_reading', 0, () => {
      expect(SubjectDetector.detect('阅读下面短文，回答问题')).assertEqual(Subject.CHINESE);
    });
    it('detect_english_for_latin', 0, () => {
      expect(SubjectDetector.detect('Choose the correct answer')).assertEqual(Subject.ENGLISH);
    });
  });
}
