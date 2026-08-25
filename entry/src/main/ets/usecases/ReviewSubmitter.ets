import { Mistake } from '../models/Mistake';
import { ReviewLog } from '../models/ReviewLog';
import { MistakeStatus, PointsActionType } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { DbResult } from '../common/DbResult';
import { ReviewScheduler } from './ReviewScheduler';
import { MasteryEvaluator } from './MasteryEvaluator';
import { AnalyticsTracker } from './AnalyticsTracker';
import { PointsCalculator } from './PointsCalculator';
import { StreakCalculator } from './StreakCalculator';
import { PerformanceMonitor } from '../services/PerformanceMonitor';

/**
 * 复习提交结果（D4）。
 */
export class ReviewSubmitResult {
  success: boolean = false;
  reason: string = '';
  pointsAwarded: number = 0;
  masteryAchieved: boolean = false;
  latestStatus: MistakeStatus = MistakeStatus.UNMASTERED;
}

/**
 * 原子化复习提交用例（D4/FR-006）：
 * 插入日志 → 查询该题全部日志 → 掌握判定 → 单次终态 updateMistake → 幂等发积分。
 * 串行 await 编排消除页面层并发写覆盖（MASTERED 不被回写）。
 */
export class ReviewSubmitter {
  static async submit(mistake: Mistake, log: ReviewLog): Promise<ReviewSubmitResult> {
    const result: ReviewSubmitResult = new ReviewSubmitResult();

    // 1. 插入复习日志（重复提交经主键冲突自然幂等）
    const insertRes: DbResult = await dbHelper.insertReviewLog(log);
    if (!insertRes.success) {
      result.reason = insertRes.reason;
      PerformanceMonitor.writeFault('review_submit_failed', { 'stage': 'insert_log' });
      return result;
    }

    // 2. 查询该题全部日志做掌握判定
    const logs: ReviewLog[] = await dbHelper.queryReviewLogs(mistake.id);

    // 3. 调度下次复习 + 首次复习时长
    ReviewScheduler.scheduleNextReview(mistake, log.correct);
    if (mistake.firstReviewDuration === 0) {
      mistake.firstReviewDuration = log.durationSeconds;
    }

    // 4. 掌握判定：终态一次性写入，不再产生第二次状态写
    if (logs.length > 0) {
      const newStatus: MistakeStatus = MasteryEvaluator.evaluateMastery(mistake, logs);
      if (newStatus === MistakeStatus.MASTERED && mistake.status !== MistakeStatus.MASTERED) {
        result.masteryAchieved = true;
      }
      if (newStatus === MistakeStatus.MASTERED) {
        mistake.status = MistakeStatus.MASTERED;
      }
    }

    // 5. 单次终态 updateMistake
    const updateRes: DbResult = await dbHelper.updateMistake(mistake);
    if (!updateRes.success) {
      result.reason = updateRes.reason;
      PerformanceMonitor.writeFault('review_submit_failed', { 'stage': 'update_mistake' });
      return result;
    }
    result.latestStatus = mistake.status;

    // 6. 积分：按确定性 ID 幂等（当日去重，重复提交不重复发分）
    if (log.correct && log.pointsAwarded > 0) {
      const awarded: number = await ReviewSubmitter.awardOnce(
        `pts_${log.clientOperationId}`, mistake.studentId,
        PointsActionType.ON_TIME_REVIEW, log.pointsAwarded);
      result.pointsAwarded += awarded;
    }
    if (result.masteryAchieved) {
      const masteryPoints: number = PointsCalculator.getPointsForAction(PointsActionType.MASTERY_ACHIEVED);
      const awardedMastery: number = await ReviewSubmitter.awardOnce(
        `pts_m_${mistake.id}`, mistake.studentId,
        PointsActionType.MASTERY_ACHIEVED, masteryPoints);
      result.pointsAwarded += awardedMastery;
    }

    // 6.5 连击积分（T033/FR-016）：按日去重，当日仅发放一次
    const activeDays: string[] = await dbHelper.queryActiveDays(mistake.studentId);
    const lastStreakDay: string = await dbHelper.queryLastPointsActionDay(mistake.studentId, PointsActionType.STREAK);
    if (StreakCalculator.shouldAwardToday(activeDays, lastStreakDay)) {
      const streakPoints: number = PointsCalculator.getPointsForAction(PointsActionType.STREAK);
      const awardedStreak: number = await ReviewSubmitter.awardOnce(
        `pts_streak_${StreakCalculator.todayIso()}`, mistake.studentId,
        PointsActionType.STREAK, streakPoints);
      result.pointsAwarded += awardedStreak;
    }

    // 7. 埋点
    AnalyticsTracker.trackReviewSubmit(mistake.studentId, log.correct, log.inputMethod as string);
    if (result.masteryAchieved) {
      AnalyticsTracker.trackMastery(mistake.studentId);
    }
    PerformanceMonitor.writeBehavior('review_submit', {
      'correct': log.correct, 'input_method': log.inputMethod as string, 'duration': log.durationSeconds
    });

    result.success = true;
    return result;
  }

  /**
   * 幂等发分：积分日志 ID 确定性生成（含来源标识），已存在则跳过。
   */
  static async awardOnce(pointsLogId: string, studentId: string,
    actionType: PointsActionType, points: number): Promise<number> {
    if (points <= 0) {
      return 0;
    }
    const exists: boolean = await dbHelper.hasPointsLog(pointsLogId);
    if (exists) {
      return 0;
    }
    const log = PointsCalculator.createPointsLog(pointsLogId, studentId, actionType);
    log.points = points;
    const res: DbResult = await dbHelper.insertPointsLog(log);
    if (!res.success) {
      PerformanceMonitor.warn('award points failed: ' + res.reason);
      return 0;
    }
    return points;
  }
}
