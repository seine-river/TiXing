import { AiLessonScene } from '../services/AiService';

/**
 * AI 讲解时间轴工具。
 *
 * 讲解脚本里的 totalDuration 可能与各场景 duration 之和不一致，
 * 进度条和拖动定位必须统一以“实际场景时长之和”为准。
 */
export class LessonSeekTarget {
  sceneIndex: number = 0;
  sceneElapsed: number = 0;
  finished: boolean = false;
}

export class LessonTimeline {
  static totalDuration(scenes: AiLessonScene[]): number {
    let total: number = 0;
    for (let index: number = 0; index < scenes.length; index++) {
      total += Math.max(1, scenes[index].duration);
    }
    return Math.max(1, total);
  }

  static resolve(seconds: number, scenes: AiLessonScene[]): LessonSeekTarget {
    const target: LessonSeekTarget = new LessonSeekTarget();
    if (scenes.length === 0) {
      return target;
    }

    const total: number = LessonTimeline.totalDuration(scenes);
    const clamped: number = Math.min(Math.max(0, Math.round(seconds)), total);
    if (clamped >= total) {
      target.sceneIndex = scenes.length - 1;
      target.sceneElapsed = Math.max(1, scenes[scenes.length - 1].duration);
      target.finished = true;
      return target;
    }

    let remaining: number = clamped;
    for (let index: number = 0; index < scenes.length; index++) {
      const duration: number = Math.max(1, scenes[index].duration);
      if (remaining < duration || index === scenes.length - 1) {
        target.sceneIndex = index;
        target.sceneElapsed = Math.min(remaining, duration);
        return target;
      }
      remaining -= duration;
    }
    return target;
  }
}
