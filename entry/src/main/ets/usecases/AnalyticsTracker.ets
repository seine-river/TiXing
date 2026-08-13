import { AnalyticsEvent } from '../models/AnalyticsEvent';
import { dbHelper } from '../repository/DatabaseHelper';
import { generateId } from '../common/Constants';

export class AnalyticsTracker {
  static trackCapture(studentId: string): void {
    dbHelper.insertAnalyticsEvent(AnalyticsEvent.create(generateId(), 'capture', studentId, '{}'));
  }

  static trackOcrConfirm(studentId: string, confidence: number, lowConfidence: boolean): void {
    const props: string = `{"confidence":${confidence},"low_confidence":${lowConfidence}}`;
    dbHelper.insertAnalyticsEvent(AnalyticsEvent.create(generateId(), 'ocr_confirm', studentId, props));
  }

  static trackReviewSubmit(studentId: string, correct: boolean, inputMethod: string): void {
    const props: string = `{"correct":${correct},"input_method":"${inputMethod}"}`;
    dbHelper.insertAnalyticsEvent(AnalyticsEvent.create(generateId(), 'review_submit', studentId, props));
  }

  static trackMastery(studentId: string): void {
    dbHelper.insertAnalyticsEvent(AnalyticsEvent.create(generateId(), 'mastery_achieved', studentId, '{}'));
  }

  static trackCommunityShare(studentId: string): void {
    dbHelper.insertAnalyticsEvent(AnalyticsEvent.create(generateId(), 'community_share', studentId, '{}'));
  }
}
