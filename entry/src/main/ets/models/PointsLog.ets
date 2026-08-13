import { PointsActionType } from './Enums';

export class PointsLog {
  id: string = '';
  studentId: string = '';
  actionType: PointsActionType = PointsActionType.CAPTURE;
  points: number = 0;
  createdAt: number = 0;

  static create(id: string, studentId: string, actionType: PointsActionType, points: number): PointsLog {
    const log = new PointsLog();
    log.id = id;
    log.studentId = studentId;
    log.actionType = actionType;
    log.points = points;
    log.createdAt = Date.now();
    return log;
  }
}

export class PointsSummary {
  totalPoints: number = 0;
  todayPoints: number = 0;
  streakDays: number = 0;
}
