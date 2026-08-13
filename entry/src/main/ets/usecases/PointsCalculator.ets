import { PointsActionType } from '../models/Enums';
import { PointsLog } from '../models/PointsLog';

const POINTS_MAP: Record<string, number> = {
  'capture': 5,
  'on_time_review': 10,
  'mastery_achieved': 20,
  'streak': 15,
  'community_contribution': 3
};

export class PointsCalculator {
  static getPointsForAction(actionType: PointsActionType): number {
    const key: string = actionType as string;
    const val = POINTS_MAP[key];
    if (val !== undefined) {
      return val;
    }
    return 0;
  }

  static createPointsLog(id: string, studentId: string, actionType: PointsActionType): PointsLog {
    const points = PointsCalculator.getPointsForAction(actionType);
    return PointsLog.create(id, studentId, actionType, points);
  }
}
