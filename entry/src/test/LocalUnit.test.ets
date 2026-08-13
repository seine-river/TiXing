import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { Mistake, OcrFieldResult, OcrRecognitionResult, ImageRegion, ImageQualityResult } from '../main/ets/models/Mistake';
import { ReviewLog } from '../main/ets/models/ReviewLog';
import { PointsLog, PointsSummary } from '../main/ets/models/PointsLog';
import { KnowledgeTag, KnowledgeProfile } from '../main/ets/models/KnowledgeTag';
import { Student, ParentAccount } from '../main/ets/models/Student';
import { CommunityPost } from '../main/ets/models/CommunityPost';
import { ReminderSettings } from '../main/ets/models/ReminderSettings';
import { AnalyticsEvent } from '../main/ets/models/AnalyticsEvent';
import { RedeemableItem, RedeemableCategory } from '../main/ets/models/RedeemableItem';
import {
  MistakeStatus, AnswerType, GradingMethod, InputMethod, Subject, ErrorType,
  PointsActionType, ContentType, ImageQualityIssue, Trend, SyncStatus, Grade, TextbookVersion
} from '../main/ets/models/Enums';
import { ReviewScheduler } from '../main/ets/usecases/ReviewScheduler';
import { MasteryEvaluator } from '../main/ets/usecases/MasteryEvaluator';
import { PointsCalculator } from '../main/ets/usecases/PointsCalculator';
import { SubjectDetector } from '../main/ets/usecases/SubjectDetector';
import {
  subjectLabel, statusLabel, statusColor, formatDate, generateId
} from '../main/ets/common/Constants';

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

    it('scheduleNextReview_sets_next_review_date_in_future', 0, () => {
      const mistake = new Mistake();
      mistake.intervalIndex = 0;
      const before: number = Date.now();
      ReviewScheduler.scheduleNextReview(mistake, true);
      expect(mistake.nextReviewDate).assertLarger(before);
    });

    it('getIntervalsDays_returns_5_intervals', 0, () => {
      const intervals = ReviewScheduler.getIntervalsDays();
      expect(intervals.length).assertEqual(5);
      expect(intervals[0]).assertEqual(1);
      expect(intervals[4]).assertEqual(30);
    });

    it('getNextIntervalDays_valid_index', 0, () => {
      expect(ReviewScheduler.getNextIntervalDays(0)).assertEqual(1);
      expect(ReviewScheduler.getNextIntervalDays(2)).assertEqual(7);
    });

    it('getNextIntervalDays_out_of_range_returns_first', 0, () => {
      expect(ReviewScheduler.getNextIntervalDays(-1)).assertEqual(1);
      expect(ReviewScheduler.getNextIntervalDays(99)).assertEqual(1);
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
      log1.reviewTime = new Date(2026, 0, 2).getTime();
      const log2 = ReviewLog.create('2', 'm1', GradingMethod.OBJECTIVE_AUTO, InputMethod.SELECT, false, 30, 0);
      log2.reviewTime = new Date(2026, 0, 1).getTime();
      const result = MasteryEvaluator.evaluateMastery(mistake, [log1, log2]);
      expect(result).assertEqual(MistakeStatus.UNMASTERED);
    });

    it('evaluateMastery_subjective_requires_more_correct', 0, () => {
      const mistake = new Mistake();
      mistake.firstReviewDuration = 60;
      const log1 = ReviewLog.create('1', 'm1', GradingMethod.SUBJECTIVE_SELFREPORT, InputMethod.KEYBOARD, true, 30, 0);
      log1.reviewTime = new Date(2026, 0, 2).getTime();
      const log2 = ReviewLog.create('2', 'm1', GradingMethod.SUBJECTIVE_SELFREPORT, InputMethod.KEYBOARD, true, 25, 0);
      log2.reviewTime = new Date(2026, 0, 1).getTime();
      const result = MasteryEvaluator.evaluateMastery(mistake, [log1, log2]);
      expect(result).assertEqual(MistakeStatus.UNMASTERED);
    });

    it('evaluateMastery_subjective_three_correct_distinct_mastered', 0, () => {
      const mistake = new Mistake();
      mistake.firstReviewDuration = 60;
      const log1 = ReviewLog.create('1', 'm1', GradingMethod.SUBJECTIVE_SELFREPORT, InputMethod.KEYBOARD, true, 30, 0);
      log1.reviewTime = new Date(2026, 0, 3).getTime();
      const log2 = ReviewLog.create('2', 'm1', GradingMethod.SUBJECTIVE_SELFREPORT, InputMethod.KEYBOARD, true, 25, 0);
      log2.reviewTime = new Date(2026, 0, 2).getTime();
      const log3 = ReviewLog.create('3', 'm1', GradingMethod.SUBJECTIVE_SELFREPORT, InputMethod.KEYBOARD, true, 25, 0);
      log3.reviewTime = new Date(2026, 0, 1).getTime();
      const result = MasteryEvaluator.evaluateMastery(mistake, [log1, log2, log3]);
      expect(result).assertEqual(MistakeStatus.MASTERED);
    });

    it('evaluateMastery_too_slow_returns_unmastered', 0, () => {
      const mistake = new Mistake();
      mistake.firstReviewDuration = 30;
      const log1 = ReviewLog.create('1', 'm1', GradingMethod.OBJECTIVE_AUTO, InputMethod.SELECT, true, 25, 0);
      log1.reviewTime = new Date(2026, 0, 2).getTime();
      const log2 = ReviewLog.create('2', 'm1', GradingMethod.OBJECTIVE_AUTO, InputMethod.SELECT, true, 30, 0);
      log2.reviewTime = new Date(2026, 0, 1).getTime();
      const result = MasteryEvaluator.evaluateMastery(mistake, [log1, log2]);
      expect(result).assertEqual(MistakeStatus.UNMASTERED);
    });

    it('evaluateMastery_same_day_returns_unmastered', 0, () => {
      const mistake = new Mistake();
      mistake.firstReviewDuration = 60;
      const log1 = ReviewLog.create('1', 'm1', GradingMethod.OBJECTIVE_AUTO, InputMethod.SELECT, true, 30, 0);
      log1.reviewTime = new Date(2026, 0, 1, 10, 0).getTime();
      const log2 = ReviewLog.create('2', 'm1', GradingMethod.OBJECTIVE_AUTO, InputMethod.SELECT, true, 25, 0);
      log2.reviewTime = new Date(2026, 0, 1, 20, 0).getTime();
      const result = MasteryEvaluator.evaluateMastery(mistake, [log1, log2]);
      expect(result).assertEqual(MistakeStatus.UNMASTERED);
    });

    it('evaluateMastery_uses_default_baseline_when_zero', 0, () => {
      const mistake = new Mistake();
      mistake.firstReviewDuration = 0;
      const log1 = ReviewLog.create('1', 'm1', GradingMethod.OBJECTIVE_AUTO, InputMethod.SELECT, true, 30, 0);
      log1.reviewTime = new Date(2026, 0, 2).getTime();
      const log2 = ReviewLog.create('2', 'm1', GradingMethod.OBJECTIVE_AUTO, InputMethod.SELECT, true, 30, 0);
      log2.reviewTime = new Date(2026, 0, 1).getTime();
      const result = MasteryEvaluator.evaluateMastery(mistake, [log1, log2]);
      expect(result).assertEqual(MistakeStatus.MASTERED);
    });

    it('resetMastery_resets_state', 0, () => {
      const mistake = new Mistake();
      mistake.status = MistakeStatus.MASTERED;
      mistake.intervalIndex = 4;
      MasteryEvaluator.resetMastery(mistake);
      expect(mistake.status).assertEqual(MistakeStatus.REVIEWING);
      expect(mistake.intervalIndex).assertEqual(0);
      expect(mistake.nextReviewDate).assertLarger(0);
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

    it('getPointsForAction_streak_returns_15', 0, () => {
      expect(PointsCalculator.getPointsForAction(PointsActionType.STREAK)).assertEqual(15);
    });

    it('getPointsForAction_community_returns_3', 0, () => {
      expect(PointsCalculator.getPointsForAction(PointsActionType.COMMUNITY_CONTRIBUTION)).assertEqual(3);
    });

    it('createPointsLog_creates_correct_log', 0, () => {
      const log = PointsCalculator.createPointsLog('id1', 'stu1', PointsActionType.CAPTURE);
      expect(log.points).assertEqual(5);
      expect(log.studentId).assertEqual('stu1');
      expect(log.actionType).assertEqual(PointsActionType.CAPTURE);
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

    it('detect_math_for_empty', 0, () => {
      expect(SubjectDetector.detect('')).assertEqual(Subject.MATH);
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
      expect(m.syncStatus).assertEqual(SyncStatus.PENDING);
      expect(m.nextReviewDate).assertLarger(0);
    });

    it('Mistake_default_status_is_unmastered', 0, () => {
      const m = new Mistake();
      expect(m.status).assertEqual(MistakeStatus.UNMASTERED);
      expect(m.errorType).assertEqual(ErrorType.OTHER);
    });

    it('ImageQualityResult_ok_and_fail', 0, () => {
      const ok = ImageQualityResult.ok();
      expect(ok.passed).assertEqual(true);
      const fail = ImageQualityResult.fail(ImageQualityIssue.BLUR);
      expect(fail.passed).assertEqual(false);
      expect(fail.issue).assertEqual(ImageQualityIssue.BLUR);
    });

    it('OcrFieldResult_and_RecognitionResult_defaults', 0, () => {
      const f = new OcrFieldResult('abc', 0.9, ContentType.PRINTED_TEXT);
      expect(f.text).assertEqual('abc');
      expect(f.confidence).assertEqual(0.9);
      const r = new OcrRecognitionResult();
      expect(r.questionText.text).assertEqual('');
    });

    it('ImageRegion_constructor', 0, () => {
      const region = new ImageRegion(1, 2, 3, 4);
      expect(region.x).assertEqual(1);
      expect(region.width).assertEqual(3);
    });
  });

  describe('Models', () => {
    it('ReviewLog_create', 0, () => {
      const log = ReviewLog.create('l1', 'm1', GradingMethod.OBJECTIVE_AUTO, InputMethod.NUMERIC_KEYPAD, true, 12, 10);
      expect(log.mistakeId).assertEqual('m1');
      expect(log.correct).assertEqual(true);
      expect(log.durationSeconds).assertEqual(12);
      expect(log.clientOperationId).assertEqual('l1');
      expect(log.reviewTime).assertLarger(0);
    });

    it('PointsLog_create_and_summary_defaults', 0, () => {
      const log = PointsLog.create('p1', 's1', PointsActionType.CAPTURE, 5);
      expect(log.points).assertEqual(5);
      expect(log.createdAt).assertLarger(0);
      const summary = new PointsSummary();
      expect(summary.totalPoints).assertEqual(0);
    });

    it('ReminderSettings_create', 0, () => {
      const r = ReminderSettings.create('stu1');
      expect(r.studentId).assertEqual('stu1');
      expect(r.dailyLimit).assertEqual(10);
      expect(r.notificationEnabled).assertEqual(true);
      expect(r.mathEnabled).assertEqual(true);
    });

    it('KnowledgeTag_and_Profile_defaults', 0, () => {
      const tag = new KnowledgeTag();
      expect(tag.subject).assertEqual(Subject.MATH);
      const profile = new KnowledgeProfile();
      expect(profile.trend).assertEqual(Trend.STABLE);
      expect(profile.currentMasteryScore).assertEqual(0);
    });

    it('Student_and_Parent_defaults', 0, () => {
      const s = new Student();
      expect(s.grade).assertEqual(Grade.G3);
      expect(s.textbookVersion).assertEqual(TextbookVersion.PEP);
      expect(s.communityBrowseEnabled).assertEqual(false);
      const p = new ParentAccount();
      expect(p.subscriptionStatus.length > 0).assertTrue();
    });

    it('CommunityPost_defaults', 0, () => {
      const c = new CommunityPost();
      expect(c.likeCount).assertEqual(0);
      expect(c.collectCount).assertEqual(0);
    });

    it('RedeemableItem_defaults', 0, () => {
      const item = new RedeemableItem();
      expect(item.category).assertEqual(RedeemableCategory.AVATAR);
      expect(item.cost).assertEqual(0);
    });

    it('AnalyticsEvent_create_hashes_student_id', 0, () => {
      const e = AnalyticsEvent.create('e1', 'capture', 'stu_default', '{}');
      expect(e.eventType).assertEqual('capture');
      expect(e.studentIdHash.indexOf('h_')).assertEqual(0);
      expect(e.platform).assertEqual('harmonyos');
      const e2 = AnalyticsEvent.create('e2', 'capture', 'stu_default', '{}');
      expect(e2.studentIdHash).assertEqual(e.studentIdHash);
    });
  });

  describe('ConstantsHelpers', () => {
    it('subjectLabel_all_subjects_and_unknown', 0, () => {
      expect(subjectLabel(Subject.MATH)).assertEqual('数学');
      expect(subjectLabel(Subject.CHINESE)).assertEqual('语文');
      expect(subjectLabel(Subject.ENGLISH)).assertEqual('英语');
      expect(subjectLabel(Subject.SCIENCE)).assertEqual('科学');
      expect(subjectLabel('history')).assertEqual('history');
    });

    it('statusLabel_all_statuses', 0, () => {
      expect(statusLabel(MistakeStatus.MASTERED)).assertEqual('已掌握');
      expect(statusLabel(MistakeStatus.REVIEWING)).assertEqual('复习中');
      expect(statusLabel(MistakeStatus.UNMASTERED)).assertEqual('未掌握');
    });

    it('statusColor_all_statuses', 0, () => {
      expect(statusColor(MistakeStatus.MASTERED)).assertEqual('#67C23A');
      expect(statusColor(MistakeStatus.REVIEWING)).assertEqual('#409EFF');
      expect(statusColor(MistakeStatus.UNMASTERED)).assertEqual('#F56C6C');
    });

    it('formatDate_pads_single_digit', 0, () => {
      const d = new Date(2026, 0, 5).getTime();
      expect(formatDate(d)).assertEqual('2026-01-05');
    });

    it('formatDate_double_digit', 0, () => {
      const d = new Date(2026, 10, 23).getTime();
      expect(formatDate(d)).assertEqual('2026-11-23');
    });

    it('generateId_nonempty_and_unique', 0, () => {
      const a = generateId();
      const b = generateId();
      expect(a.length > 0).assertTrue();
      expect(a !== b).assertTrue();
    });
  });
}
