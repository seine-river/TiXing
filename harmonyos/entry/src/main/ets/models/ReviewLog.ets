import { GradingMethod, InputMethod } from './Enums';

export class ReviewLog {
  id: string = '';
  mistakeId: string = '';
  reviewTime: number = 0;
  gradingMethod: GradingMethod = GradingMethod.OBJECTIVE_AUTO;
  inputMethod: InputMethod = InputMethod.SELECT;
  correct: boolean = false;
  durationSeconds: number = 0;
  pointsAwarded: number = 0;
  clientOperationId: string = '';

  static create(
    id: string,
    mistakeId: string,
    gradingMethod: GradingMethod,
    inputMethod: InputMethod,
    correct: boolean,
    durationSeconds: number,
    pointsAwarded: number
  ): ReviewLog {
    const log = new ReviewLog();
    log.id = id;
    log.mistakeId = mistakeId;
    log.reviewTime = Date.now();
    log.gradingMethod = gradingMethod;
    log.inputMethod = inputMethod;
    log.correct = correct;
    log.durationSeconds = durationSeconds;
    log.pointsAwarded = pointsAwarded;
    log.clientOperationId = id;
    return log;
  }
}
