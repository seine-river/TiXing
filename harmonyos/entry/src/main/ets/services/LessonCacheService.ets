import fs from '@ohos.file.fs';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AiLesson } from './AiService';
import { AppContextHolder } from '../common/AppContext';

const LOG_DOMAIN: number = 0xA009;
const LOG_TAG: string = 'TiXingLessonCache';

interface CachedLessonRecord {
  sourceFingerprint: string;
  savedAt: number;
  lesson: AiLesson;
}

/**
 * AI 讲解脚本本地缓存。
 * 讲解“视频”由脚本 + 本地动画 + TTS 实时渲染，因此持久化脚本即可完整复原播放内容。
 */
export class LessonCacheService {
  static async load(mistakeId: string, sourceFingerprint: string): Promise<AiLesson | undefined> {
    if (mistakeId.length === 0) {
      return undefined;
    }
    const path: string = LessonCacheService.cachePath(mistakeId);
    try {
      if (!fs.accessSync(path)) {
        return undefined;
      }
      const text: string = fs.readTextSync(path);
      const record: CachedLessonRecord = JSON.parse(text) as CachedLessonRecord;
      if (record.sourceFingerprint !== sourceFingerprint) {
        hilog.info(LOG_DOMAIN, LOG_TAG,
          'lesson cache source changed: mistakeId=%{public}s', mistakeId);
        LessonCacheService.remove(mistakeId);
        return undefined;
      }
      const lesson: AiLesson = record.lesson;
      if (lesson === undefined || lesson.scenes === undefined || lesson.scenes.length === 0) {
        LessonCacheService.remove(mistakeId);
        return undefined;
      }
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'lesson cache hit: mistakeId=%{public}s, sceneCount=%{public}d, bytes=%{public}d',
        mistakeId, lesson.scenes.length, text.length);
      return lesson;
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG,
        'lesson cache read failed and will be removed: mistakeId=%{public}s, error=%{public}s',
        mistakeId, e instanceof Error ? e.message : `${e}`);
      LessonCacheService.remove(mistakeId);
      return undefined;
    }
  }

  static async save(mistakeId: string, sourceFingerprint: string, lesson: AiLesson): Promise<void> {
    if (mistakeId.length === 0 || lesson.scenes.length === 0) {
      return;
    }
    try {
      const directory: string = LessonCacheService.cacheDirectory();
      if (!fs.accessSync(directory)) {
        fs.mkdirSync(directory, true);
      }
      const record: CachedLessonRecord = {
        sourceFingerprint: sourceFingerprint,
        savedAt: Date.now(),
        lesson: lesson
      };
      const text: string = JSON.stringify(record);
      LessonCacheService.writeText(LessonCacheService.cachePath(mistakeId), text);
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'lesson cache saved: mistakeId=%{public}s, sceneCount=%{public}d, bytes=%{public}d',
        mistakeId, lesson.scenes.length, text.length);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG,
        'lesson cache save failed: mistakeId=%{public}s, error=%{public}s',
        mistakeId, e instanceof Error ? e.message : `${e}`);
    }
  }

  static remove(mistakeId: string): void {
    if (mistakeId.length === 0) {
      return;
    }
    try {
      const path: string = LessonCacheService.cachePath(mistakeId);
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'lesson cache remove failed: mistakeId=%{public}s', mistakeId);
    }
  }

  private static cachePath(mistakeId: string): string {
    return `${LessonCacheService.cacheDirectory()}/${encodeURIComponent(mistakeId)}.json`;
  }

  private static cacheDirectory(): string {
    return AppContextHolder.require().filesDir + '/lesson_cache';
  }

  private static writeText(path: string, text: string): void {
    const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, text);
    } finally {
      fs.closeSync(file);
    }
  }
}
