import { AnalyticsEvent } from '../models/AnalyticsEvent';
import { dbHelper } from '../repository/DatabaseHelper';
import { DbResult } from '../common/DbResult';
import { generateId } from '../common/Constants';
import { PerformanceMonitor } from '../services/PerformanceMonitor';

/**
 * 埋点追踪（T040）：全部 track* 带 catch（写失败记日志不崩），
 * properties 经类型化对象 JSON.stringify 构建，不做裸字符串内插。
 */
export class AnalyticsTracker {
  private static track(eventType: string, studentId: string, props: Record<string, string | number | boolean>): void {
    const event: AnalyticsEvent = AnalyticsEvent.create(generateId(), eventType, studentId, JSON.stringify(props));
    dbHelper.insertAnalyticsEvent(event).then((res: DbResult): void => {
      if (!res.success) {
        PerformanceMonitor.warn(`analytics ${eventType} write failed`);
      }
    }).catch((_e: Object): void => {
      PerformanceMonitor.warn(`analytics ${eventType} write rejected`);
    });
  }

  static trackCapture(studentId: string): void {
    AnalyticsTracker.track('capture', studentId, {});
  }

  /** AI 识别确认（原 ocr_confirm）：记录识别来源与结果，供运营观测 AI 通道成功率。 */
  static trackAiConfirm(studentId: string, success: boolean, byManual: boolean): void {
    AnalyticsTracker.track('ai_confirm', studentId, { 'success': success, 'by_manual': byManual });
  }

  static trackReviewSubmit(studentId: string, correct: boolean, inputMethod: string): void {
    AnalyticsTracker.track('review_submit', studentId, { 'correct': correct, 'input_method': inputMethod });
  }

  static trackMastery(studentId: string): void {
    AnalyticsTracker.track('mastery_achieved', studentId, {});
  }

  static trackCommunityShare(studentId: string): void {
    AnalyticsTracker.track('community_share', studentId, {});
  }
}
