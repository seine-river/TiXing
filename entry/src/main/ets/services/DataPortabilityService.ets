import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import zlib from '@ohos.zlib';
import { taskpool } from '@kit.ArkTS';
import { Mistake } from '../models/Mistake';
import { ReviewLog } from '../models/ReviewLog';
import { ReminderSettings } from '../models/ReminderSettings';
import { Subject, ErrorType, MistakeStatus, AnswerType, GradingMethod, InputMethod } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { DbResult } from '../common/DbResult';
import { AppContextHolder } from '../common/AppContext';
import { PerformanceMonitor } from './PerformanceMonitor';
import { KnowledgeProfileAggregator } from '../usecases/KnowledgeProfileAggregator';

const BUNDLE_APP: string = 'tixing';
const BUNDLE_VERSION: number = 2;
const MAX_BUNDLE_SIZE: number = 10 * 1024 * 1024;
const EXPORT_KEEP_COUNT: number = 3;
const PREVIEW_ITEM_LIMIT: number = 10;

interface BundleManifest {
  app: string;
  version: number;
  exportedAt: number;
  studentId: string;
}

interface ExportMistake {
  id: string;
  studentId: string;
  imageUrl: string;
  ocrText: string;
  ocrConfidence: number;
  isConfirmed: boolean;
  subject: string;
  knowledgeTagIds: string[];
  errorType: string;
  status: string;
  intervalIndex: number;
  nextReviewDate: number;
  firstReviewDuration: number;
  standardAnswer: string;
  studentAnswer: string;
  knowledgeSummary: string;
  answerType: string;
  notes: string;
  notesAttachmentUrl: string;
  createdAt: number;
}

interface ExportLog {
  id: string;
  mistakeId: string;
  reviewTime: number;
  gradingMethod: string;
  inputMethod: string;
  correct: boolean;
  durationSeconds: number;
  pointsAwarded: number;
  clientOperationId: string;
}

interface ExportSettings {
  reviewTimeStart: string;
  reviewTimeEnd: string;
  dailyLimit: number;
  mathEnabled: boolean;
  chineseEnabled: boolean;
  englishEnabled: boolean;
  scienceEnabled: boolean;
  doNotDisturb: boolean;
  notificationEnabled: boolean;
}

interface ExportDataRoot {
  mistakes: ExportMistake[];
  reviewLogs: ExportLog[];
  settings: ExportSettings;
}

/** taskpool 内部使用的解析结果（JSON 字符串载体，保持 sendable）。 */
interface TaskSummary {
  ok: boolean;
  reason: string;
  bundleRoot: string;
  exportedAt: number;
  mistakeCount: number;
  logCount: number;
  imageCount: number;
  preview: PreviewItemRaw[];
}

interface PreviewItemRaw {
  id: string;
  subject: string;
  ocrText: string;
  createdAt: number;
}

export class BundlePreviewItem {
  id: string = '';
  subject: string = '';
  ocrText: string = '';
  createdAt: number = 0;
}

class ExportZipEntry {
  path: string = '';
  mtime: number = 0;
}

export class BundlePreview {
  zipPath: string = '';
  bundleRoot: string = '';
  mistakeCount: number = 0;
  logCount: number = 0;
  imageCount: number = 0;
  exportedAt: number = 0;
  previewItems: BundlePreviewItem[] = [];
}

/**
 * 后台解析任务（T026/FR-014）：解压 + 校验 + 统计在 taskpool 执行，避免大文件冻结 UI。
 * 返回 JSON 字符串（sendable），主线程反序列化为轻量预览。
 */
@Concurrent
async function parseBundleTask(zipPath: string, extractDir: string, previewLimit: number): Promise<string> {
  // @Concurrent 函数只能引用 import 变量或局部变量，故定位逻辑以内嵌局部函数实现
  const findRoot = (dir: string): string => {
    try {
      if (fs.accessSync(dir + '/manifest.json')) {
        return dir;
      }
      const entries: string[] = fs.listFileSync(dir);
      for (const entry of entries) {
        const sub: string = dir + '/' + entry;
        const stat = fs.statSync(sub);
        if (stat.isDirectory() && fs.accessSync(sub + '/manifest.json')) {
          return sub;
        }
      }
    } catch (e) {
    }
    return '';
  };
  const summary: TaskSummary = {
    ok: false,
    reason: '',
    bundleRoot: '',
    exportedAt: 0,
    mistakeCount: 0,
    logCount: 0,
    imageCount: 0,
    preview: []
  };
  try {
    fs.mkdirSync(extractDir, true);
    const zlibOpts: zlib.Options = {};
    await zlib.decompressFile(zipPath, extractDir, zlibOpts);
    const root: string = findRoot(extractDir);
    if (root.length === 0) {
      summary.reason = '备份包结构不正确（缺少 manifest.json）';
      return JSON.stringify(summary);
    }
    summary.bundleRoot = root;
    const manifestText: string = fs.readTextSync(root + '/manifest.json');
    const manifest: BundleManifest = JSON.parse(manifestText) as BundleManifest;
    if (manifest.app !== 'tixing') {
      summary.reason = '不是题醒应用的备份文件';
      return JSON.stringify(summary);
    }
    if (manifest.version > 2) {
      summary.reason = '备份版本过新，请升级应用后导入';
      return JSON.stringify(summary);
    }
    const dataText: string = fs.readTextSync(root + '/data.json');
    const data: ExportDataRoot = JSON.parse(dataText) as ExportDataRoot;
    summary.exportedAt = manifest.exportedAt;
    summary.mistakeCount = data.mistakes !== undefined ? data.mistakes.length : 0;
    summary.logCount = data.reviewLogs !== undefined ? data.reviewLogs.length : 0;
    const imagesDir: string = root + '/images';
    if (fs.accessSync(imagesDir)) {
      const files: string[] = fs.listFileSync(imagesDir);
      for (const f of files) {
        if (f.endsWith('.jpg')) {
          summary.imageCount++;
        }
      }
    }
    const items: PreviewItemRaw[] = [];
    if (data.mistakes !== undefined) {
      for (let i: number = 0; i < data.mistakes.length && i < previewLimit; i++) {
        const m: ExportMistake = data.mistakes[i];
        const item: PreviewItemRaw = {
          id: m.id,
          subject: m.subject,
          ocrText: m.ocrText !== undefined && m.ocrText.length > 30 ? m.ocrText.substring(0, 30) + '...' : m.ocrText,
          createdAt: m.createdAt
        };
        items.push(item);
      }
    }
    summary.preview = items;
    summary.ok = summary.mistakeCount > 0;
    if (!summary.ok) {
      summary.reason = '备份包中没有错题数据';
    }
    return JSON.stringify(summary);
  } catch (e) {
    summary.reason = '备份包解析失败：文件损坏或格式不正确';
    return JSON.stringify(summary);
  }
}

/** 递归删除目录（fs.rmdirSync 仅支持空目录，此处自底向上清理）。 */
function removeDirRecursive(dir: string): void {
  try {
    if (!fs.accessSync(dir)) {
      return;
    }
    const entries: string[] = fs.listFileSync(dir);
    for (const entry of entries) {
      const full: string = dir + '/' + entry;
      const stat = fs.statSync(full);
      if (stat.isDirectory()) {
        removeDirRecursive(full);
      } else {
        fs.unlinkSync(full);
      }
    }
    fs.rmdirSync(dir);
  } catch (e) {
  }
}

/** 在解压目录中定位 manifest.json 所在根目录（兼容压缩目录嵌套）——已内聚至 parseBundleTask 局部函数。 */

/**
 * 数据导入导出服务（T025–T027/D6）：zip 备份包 = manifest.json + data.json + images/。
 */
export class DataPortabilityService {
  /**
   * 导出（T025/FR-013）：错题 + 复习记录 + 图片打包为单个 zip；导出目录仅保留最近 3 份。
   * 失败 throw；成功返回 zip 路径。
   */
  static async exportBundle(studentId: string): Promise<string> {
    const mistakes: Mistake[] = await dbHelper.queryMistakesByStudent(studentId);
    const logs: ReviewLog[] = await dbHelper.queryReviewLogsByStudent(studentId);
    const settings: ReminderSettings = await dbHelper.queryReminderSettings(studentId);

    const ctx = AppContextHolder.require();
    const stagingDir: string = `${ctx.cacheDir}/export_staging_${Date.now()}`;
    const imagesDir: string = `${stagingDir}/images`;
    fs.mkdirSync(imagesDir, true);

    try {
      const manifest: BundleManifest = {
        app: BUNDLE_APP,
        version: BUNDLE_VERSION,
        exportedAt: Date.now(),
        studentId: studentId
      };
      DataPortabilityService.writeText(`${stagingDir}/manifest.json`, JSON.stringify(manifest));

      const mistakesArr: ExportMistake[] = [];
      const ownedDir: string = ctx.filesDir + '/mistakes';
      for (const m of mistakes) {
        const em: ExportMistake = {
          id: m.id, studentId: m.studentId, imageUrl: m.imageUrl,
          ocrText: m.ocrText, ocrConfidence: m.ocrConfidence,
          isConfirmed: m.isConfirmed, subject: m.subject,
          knowledgeTagIds: m.knowledgeTagIds, errorType: m.errorType,
          status: m.status, intervalIndex: m.intervalIndex,
          nextReviewDate: m.nextReviewDate, firstReviewDuration: m.firstReviewDuration,
          standardAnswer: m.standardAnswer, studentAnswer: m.studentAnswer,
          knowledgeSummary: m.knowledgeSummary, answerType: m.answerType,
          notes: m.notes, notesAttachmentUrl: m.notesAttachmentUrl,
          createdAt: m.createdAt
        };
        mistakesArr.push(em);
        // 本机图片随包迁移，按 mistakeId 命名
        if (m.imageUrl.length > 0 && m.imageUrl.startsWith(ownedDir)) {
          try {
            if (fs.accessSync(m.imageUrl)) {
              fs.copyFileSync(m.imageUrl, `${imagesDir}/${m.id}.jpg`);
            }
          } catch (e) {
            PerformanceMonitor.warn('export copy image failed: ' + m.id);
          }
        }
      }
      const logsArr: ExportLog[] = [];
      for (const l of logs) {
        const el: ExportLog = {
          id: l.id, mistakeId: l.mistakeId, reviewTime: l.reviewTime,
          gradingMethod: l.gradingMethod, inputMethod: l.inputMethod,
          correct: l.correct, durationSeconds: l.durationSeconds,
          pointsAwarded: l.pointsAwarded, clientOperationId: l.clientOperationId
        };
        logsArr.push(el);
      }
      const settingsExport: ExportSettings = {
        reviewTimeStart: settings.reviewTimeStart,
        reviewTimeEnd: settings.reviewTimeEnd,
        dailyLimit: settings.dailyLimit,
        mathEnabled: settings.mathEnabled,
        chineseEnabled: settings.chineseEnabled,
        englishEnabled: settings.englishEnabled,
        scienceEnabled: settings.scienceEnabled,
        doNotDisturb: settings.doNotDisturb,
        notificationEnabled: settings.notificationEnabled
      };
      const dataRoot: ExportDataRoot = {
        mistakes: mistakesArr,
        reviewLogs: logsArr,
        settings: settingsExport
      };
      DataPortabilityService.writeText(`${stagingDir}/data.json`, JSON.stringify(dataRoot));

      const exportsDir: string = ctx.filesDir + '/exports';
      if (!fs.accessSync(exportsDir)) {
        fs.mkdirSync(exportsDir, true);
      }
      const zipPath: string = `${exportsDir}/tixing_backup_${DataPortabilityService.dateStamp()}_${Date.now() % 100000}.zip`;
      const zlibOpts: zlib.Options = {};
      await zlib.compressFile(stagingDir, zipPath, zlibOpts);
      if (!fs.accessSync(zipPath)) {
        throw new Error('压缩产物写入失败');
      }
      DataPortabilityService.rotateExports(exportsDir);
      return zipPath;
    } finally {
      removeDirRecursive(stagingDir);
    }
  }

  /** 选择备份文件（.zip）并拷贝到沙箱缓存目录。 */
  static async pickBundleFile(): Promise<string | undefined> {
    try {
      const docPicker = new picker.DocumentViewPicker();
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['.zip'];
      const uris: string[] = await docPicker.select(options);
      if (uris.length === 0) {
        return undefined;
      }
      const ctx = AppContextHolder.require();
      const dir: string = ctx.cacheDir + '/imports';
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
      const dest: string = `${dir}/bundle_${Date.now()}.zip`;
      const srcFile = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
      try {
        const destFile = fs.openSync(dest, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        try {
          await fs.copyFile(srcFile.fd, destFile.fd);
        } finally {
          fs.closeSync(destFile);
        }
      } finally {
        fs.closeSync(srcFile);
      }
      return dest;
    } catch (e) {
      PerformanceMonitor.warn('pick bundle file failed');
      return undefined;
    }
  }

  /**
   * 异步解析预览（T026/FR-014）：10MB 上限 + manifest 校验 + taskpool 后台执行。
   */
  static async parseBundlePreview(zipPath: string): Promise<BundlePreview> {
    const preview = new BundlePreview();
    preview.zipPath = zipPath;

    const stat = fs.statSync(zipPath);
    if (stat.size > MAX_BUNDLE_SIZE) {
      throw new Error(`备份文件超过 10MB 上限（当前 ${Math.round(stat.size / 1024 / 1024)}MB），请精简后重试`);
    }

    const ctx = AppContextHolder.require();
    const extractDir: string = `${ctx.cacheDir}/imports/extracted_${Date.now()}`;
    const summaryJson: string = await taskpool.execute(parseBundleTask, zipPath, extractDir, PREVIEW_ITEM_LIMIT) as string;
    const summary: TaskSummary = JSON.parse(summaryJson) as TaskSummary;
    if (!summary.ok) {
      throw new Error(summary.reason.length > 0 ? summary.reason : '备份包解析失败');
    }
    preview.bundleRoot = summary.bundleRoot;
    preview.exportedAt = summary.exportedAt;
    preview.mistakeCount = summary.mistakeCount;
    preview.logCount = summary.logCount;
    preview.imageCount = summary.imageCount;
    const items: BundlePreviewItem[] = [];
    for (const raw of summary.preview) {
      const item = new BundlePreviewItem();
      item.id = raw.id;
      item.subject = raw.subject;
      item.ocrText = raw.ocrText;
      item.createdAt = raw.createdAt;
      items.push(item);
    }
    preview.previewItems = items;
    return preview;
  }

  /**
   * 导入（T027/FR-013）：恢复错题 + 复习日志（按 id 去重）+ 图片回填 + 提醒设置；
   * 数据写入在单事务内完成，失败整体回滚。
   */
  static async importBundle(preview: BundlePreview): Promise<DbResult> {
    if (preview.bundleRoot.length === 0) {
      return DbResult.fail('importBundle', '备份尚未解析，请先预览确认');
    }
    const ctx = AppContextHolder.require();

    let data: ExportDataRoot;
    try {
      const dataText: string = fs.readTextSync(preview.bundleRoot + '/data.json');
      data = JSON.parse(dataText) as ExportDataRoot;
    } catch (e) {
      return DbResult.fail('importBundle', '备份数据读取失败');
    }

    const mistakes: Mistake[] = DataPortabilityService.toMistakes(data.mistakes);
    const logs: ReviewLog[] = DataPortabilityService.toLogs(data.reviewLogs);

    // 图片回填：包内图片拷贝到本机错题目录，并替换 imageUrl 为本机路径
    const ownedDir: string = ctx.filesDir + '/mistakes';
    if (!fs.accessSync(ownedDir)) {
      fs.mkdirSync(ownedDir, true);
    }
    for (const m of mistakes) {
      const bundledImage: string = `${preview.bundleRoot}/images/${m.id}.jpg`;
      try {
        if (fs.accessSync(bundledImage)) {
          const destPath: string = `${ownedDir}/import_${m.id}.jpg`;
          fs.copyFileSync(bundledImage, destPath);
          m.imageUrl = destPath;
        }
      } catch (e) {
        PerformanceMonitor.warn('import copy image failed: ' + m.id);
      }
    }

    // 事务写入：错题按 id 去重插入，日志按 id 去重插入
    const importRes: DbResult = await dbHelper.runInTransaction('importBundle', async (): Promise<DbResult> => {
      let inserted = 0;
      for (const m of mistakes) {
        const existing: Mistake | undefined = await dbHelper.queryMistakeById(m.id);
        if (existing === undefined) {
          const res: DbResult = await dbHelper.insertMistake(m);
          if (!res.success) {
            return res;
          }
          inserted++;
        }
      }
      for (const log of logs) {
        const existingLogs: ReviewLog[] = await dbHelper.queryReviewLogs(log.mistakeId);
        const dup: boolean = existingLogs.some((l: ReviewLog): boolean => l.id === log.id);
        if (!dup) {
          const res: DbResult = await dbHelper.insertReviewLog(log);
          if (!res.success) {
            return res;
          }
        }
      }
      PerformanceMonitor.writeStatistic('import_bundle', { 'inserted': inserted, 'logs': logs.length });
      return DbResult.ok();
    });
    if (!importRes.success) {
      return importRes;
    }

    // 设置恢复（事务外：saveReminderSettings 自带事务）
    if (data.settings !== undefined) {
      const s = ReminderSettings.create('stu_default');
      s.reviewTimeStart = data.settings.reviewTimeStart;
      s.reviewTimeEnd = data.settings.reviewTimeEnd;
      s.dailyLimit = data.settings.dailyLimit;
      s.mathEnabled = data.settings.mathEnabled;
      s.chineseEnabled = data.settings.chineseEnabled;
      s.englishEnabled = data.settings.englishEnabled;
      s.scienceEnabled = data.settings.scienceEnabled;
      s.doNotDisturb = data.settings.doNotDisturb;
      s.notificationEnabled = data.settings.notificationEnabled;
      await dbHelper.saveReminderSettings(s);
    }

    await KnowledgeProfileAggregator.recomputeForStudent('stu_default');
    return DbResult.ok();
  }

  /** 清理导入产生的缓存目录。 */
  static async cleanupImportCache(preview: BundlePreview): Promise<void> {
    if (preview.bundleRoot.length > 0) {
      removeDirRecursive(preview.bundleRoot);
    }
  }

  private static toMistakes(arr: ExportMistake[]): Mistake[] {
    const list: Mistake[] = [];
    for (const em of arr) {
      const m = new Mistake();
      m.id = em.id;
      m.studentId = em.studentId !== undefined && em.studentId.length > 0 ? em.studentId : 'stu_default';
      m.imageUrl = em.imageUrl !== undefined ? em.imageUrl : '';
      m.ocrText = em.ocrText !== undefined ? em.ocrText : '';
      m.ocrConfidence = em.ocrConfidence !== undefined ? em.ocrConfidence : 0;
      m.isConfirmed = em.isConfirmed === true;
      m.subject = em.subject as Subject;
      m.errorType = em.errorType as ErrorType;
      m.status = em.status as MistakeStatus;
      m.intervalIndex = em.intervalIndex !== undefined ? em.intervalIndex : 0;
      m.nextReviewDate = em.nextReviewDate !== undefined ? em.nextReviewDate : Date.now();
      m.firstReviewDuration = em.firstReviewDuration !== undefined ? em.firstReviewDuration : 0;
      m.standardAnswer = em.standardAnswer !== undefined ? em.standardAnswer : '';
      m.studentAnswer = em.studentAnswer !== undefined ? em.studentAnswer : '';
      m.knowledgeSummary = em.knowledgeSummary !== undefined ? em.knowledgeSummary : '';
      m.answerType = em.answerType as AnswerType;
      m.notes = em.notes !== undefined ? em.notes : '';
      m.notesAttachmentUrl = em.notesAttachmentUrl !== undefined ? em.notesAttachmentUrl : '';
      m.createdAt = em.createdAt !== undefined ? em.createdAt : Date.now();
      m.knowledgeTagIds = em.knowledgeTagIds !== undefined ? em.knowledgeTagIds : [];
      list.push(m);
    }
    return list;
  }

  private static toLogs(arr: ExportLog[]): ReviewLog[] {
    const list: ReviewLog[] = [];
    for (const el of arr) {
      const log = new ReviewLog();
      log.id = el.id;
      log.mistakeId = el.mistakeId;
      log.reviewTime = el.reviewTime !== undefined ? el.reviewTime : Date.now();
      log.gradingMethod = el.gradingMethod as GradingMethod;
      log.inputMethod = el.inputMethod as InputMethod;
      log.correct = el.correct === true;
      log.durationSeconds = el.durationSeconds !== undefined ? el.durationSeconds : 0;
      log.pointsAwarded = el.pointsAwarded !== undefined ? el.pointsAwarded : 0;
      log.clientOperationId = el.clientOperationId !== undefined ? el.clientOperationId : el.id;
      list.push(log);
    }
    return list;
  }

  private static writeText(path: string, text: string): void {
    const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, text);
    } finally {
      fs.closeSync(file);
    }
  }

  /** 导出目录限量（T025/FR-020）：仅保留最近 EXPORT_KEEP_COUNT 份。 */
  private static rotateExports(exportsDir: string): void {
    try {
      const names: string[] = fs.listFileSync(exportsDir);
      const zips: string[] = names.filter((n: string): boolean => n.endsWith('.zip'));
      if (zips.length <= EXPORT_KEEP_COUNT) {
        return;
      }
      const withTime: ExportZipEntry[] = [];
      for (const name of zips) {
        try {
          const stat = fs.statSync(`${exportsDir}/${name}`);
          const entry = new ExportZipEntry();
          entry.path = `${exportsDir}/${name}`;
          entry.mtime = stat.mtime;
          withTime.push(entry);
        } catch (e) {
        }
      }
      withTime.sort((a: ExportZipEntry, b: ExportZipEntry): number => b.mtime - a.mtime);
      for (let i: number = EXPORT_KEEP_COUNT; i < withTime.length; i++) {
        try {
          fs.unlinkSync(withTime[i].path);
        } catch (e) {
        }
      }
    } catch (e) {
      PerformanceMonitor.warn('rotate exports failed');
    }
  }

  private static dateStamp(): string {
    const d = new Date();
    const m: number = d.getMonth() + 1;
    const day: number = d.getDate();
    return `${d.getFullYear()}${m < 10 ? '0' + m : m}${day < 10 ? '0' + day : day}`;
  }
}
