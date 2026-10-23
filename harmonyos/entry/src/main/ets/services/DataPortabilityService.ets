import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import zlib from '@ohos.zlib';
import { taskpool } from '@kit.ArkTS';
import { Mistake } from '../models/Mistake';
import { ReviewLog } from '../models/ReviewLog';
import { ReminderSettings } from '../models/ReminderSettings';
import { Student } from '../models/Student';
import { PointsLog, RedemptionRecord } from '../models/PointsLog';
import { AnalyticsEvent } from '../models/AnalyticsEvent';
import { KnowledgeProfile } from '../models/KnowledgeTag';
import {
  Subject, ErrorType, MistakeStatus, AnswerType, GradingMethod, InputMethod,
  Grade, TextbookVersion, PointsActionType, Trend
} from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { DbResult } from '../common/DbResult';
import { AppContextHolder } from '../common/AppContext';
import { PerformanceMonitor } from './PerformanceMonitor';
import { KnowledgeProfileAggregator } from '../usecases/KnowledgeProfileAggregator';
import { VoiceAskRecord, InterestInsight } from '../models/VoiceAsk';

const BUNDLE_APP: string = 'tixing';
const BUNDLE_VERSION: number = 3;
const MAX_BUNDLE_SIZE: number = 100 * 1024 * 1024;
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

interface ExportStudent {
  id: string;
  parentId: string;
  nickname: string;
  grade: string;
  textbookVersion: string;
  region: string;
  school: string;
  communityBrowseEnabled: boolean;
  communityShareEnabled: boolean;
  createdAt: number;
}

interface ExportPointsLog {
  id: string;
  studentId: string;
  actionType: string;
  points: number;
  createdAt: number;
}

interface ExportRedemption {
  id: string;
  studentId: string;
  itemId: string;
  cost: number;
  redeemedAt: number;
}

interface ExportKnowledgeProfile {
  id: string;
  studentId: string;
  knowledgeTagId: string;
  totalMistakes: number;
  masteredCount: number;
  currentMasteryScore: number;
  trend: string;
  updatedAt: number;
}

interface ExportAnalyticsEvent {
  id: string;
  eventType: string;
  studentIdHash: string;
  platform: string;
  properties: string;
  occurredAt: number;
}

interface ExportDataRoot {
  student?: ExportStudent;
  mistakes: ExportMistake[];
  reviewLogs: ExportLog[];
  settings: ExportSettings;
  voiceAsks?: ExportVoiceAsk[];
  interestInsights?: ExportInsight[];
  pointsLogs?: ExportPointsLog[];
  redemptions?: ExportRedemption[];
  knowledgeProfiles?: ExportKnowledgeProfile[];
  analyticsEvents?: ExportAnalyticsEvent[];
}

interface ExportVoiceAsk {
  id: string;
  studentId: string;
  questionText: string;
  answerText: string;
  subject: string;
  topic: string;
  interestTags: string[];
  questionType: string;
  gradeLevel: string;
  audioPath: string;
  audioDuration: number;
  asrStatus: string;
  aiStatus: string;
  safetyLevel: string;
  status: string;
  createdAt: number;
  updatedAt: number;
}

interface ExportInsight {
  id: string;
  studentId: string;
  periodStart: number;
  periodEnd: number;
  questionCount: number;
  topSubjects: string[];
  topTopics: string[];
  interestTags: string[];
  trend: string;
  childSummary: string;
  parentSummary: string;
  recommendedActivities: string[];
  generatedAt: number;
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
  voiceAskCount: number;
  insightCount: number;
  audioCount: number;
  pointsLogCount: number;
  redemptionCount: number;
  knowledgeProfileCount: number;
  analyticsEventCount: number;
  preview: PreviewItemRaw[];
  voicePreview: VoicePreviewRaw[];
}

interface PreviewItemRaw {
  id: string;
  subject: string;
  ocrText: string;
  createdAt: number;
}

interface VoicePreviewRaw {
  id: string;
  questionText: string;
  subject: string;
  createdAt: number;
}

export class BundlePreviewItem {
  id: string = '';
  subject: string = '';
  ocrText: string = '';
  createdAt: number = 0;
}

export class VoiceBundlePreviewItem {
  id: string = '';
  questionText: string = '';
  subject: string = '';
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
  voiceAskCount: number = 0;
  insightCount: number = 0;
  audioCount: number = 0;
  pointsLogCount: number = 0;
  redemptionCount: number = 0;
  knowledgeProfileCount: number = 0;
  analyticsEventCount: number = 0;
  exportedAt: number = 0;
  previewItems: BundlePreviewItem[] = [];
  voicePreviewItems: VoiceBundlePreviewItem[] = [];
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
    voiceAskCount: 0,
    insightCount: 0,
    audioCount: 0,
    pointsLogCount: 0,
    redemptionCount: 0,
    knowledgeProfileCount: 0,
    analyticsEventCount: 0,
    preview: [],
    voicePreview: []
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
    if (manifest.version > 3) {
      summary.reason = '备份版本过新，请升级应用后导入';
      return JSON.stringify(summary);
    }
    const dataText: string = fs.readTextSync(root + '/data.json');
    const data: ExportDataRoot = JSON.parse(dataText) as ExportDataRoot;
    summary.exportedAt = manifest.exportedAt;
    summary.mistakeCount = data.mistakes !== undefined ? data.mistakes.length : 0;
    summary.logCount = data.reviewLogs !== undefined ? data.reviewLogs.length : 0;
    summary.voiceAskCount = data.voiceAsks !== undefined ? data.voiceAsks.length : 0;
    summary.insightCount = data.interestInsights !== undefined ? data.interestInsights.length : 0;
    summary.pointsLogCount = data.pointsLogs !== undefined ? data.pointsLogs.length : 0;
    summary.redemptionCount = data.redemptions !== undefined ? data.redemptions.length : 0;
    summary.knowledgeProfileCount = data.knowledgeProfiles !== undefined ? data.knowledgeProfiles.length : 0;
    summary.analyticsEventCount = data.analyticsEvents !== undefined ? data.analyticsEvents.length : 0;
    const imagesDir: string = root + '/images';
    if (fs.accessSync(imagesDir)) {
      const files: string[] = fs.listFileSync(imagesDir);
      for (const f of files) {
        if (f.endsWith('.jpg')) {
          summary.imageCount++;
        }
      }
    }
    const audioDir: string = root + '/audio';
    if (fs.accessSync(audioDir)) {
      const audioFiles: string[] = fs.listFileSync(audioDir);
      for (const f of audioFiles) {
        if (f.endsWith('.wav') || f.endsWith('.mp3')) {
          summary.audioCount++;
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
    const voicePreview: VoicePreviewRaw[] = [];
    if (data.voiceAsks !== undefined) {
      for (let i = 0; i < data.voiceAsks.length && i < previewLimit; i++) {
        const record: ExportVoiceAsk = data.voiceAsks[i];
        const item: VoicePreviewRaw = {
          id: record.id,
          questionText: record.questionText !== undefined && record.questionText.length > 34
            ? record.questionText.substring(0, 34) + '...' : record.questionText,
          subject: record.subject,
          createdAt: record.createdAt
        };
        voicePreview.push(item);
      }
    }
    summary.preview = items;
    summary.voicePreview = voicePreview;
    summary.ok = data.student !== undefined || data.settings !== undefined ||
      summary.mistakeCount > 0 || summary.logCount > 0 || summary.voiceAskCount > 0 ||
      summary.insightCount > 0 || summary.pointsLogCount > 0 || summary.redemptionCount > 0 ||
      summary.knowledgeProfileCount > 0 || summary.analyticsEventCount > 0;
    if (!summary.ok) {
      summary.reason = '备份包中没有可导入的数据';
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
    const ctx = AppContextHolder.require();
    const exportsDir: string = ctx.filesDir + '/exports';
    if (!fs.accessSync(exportsDir)) {
      fs.mkdirSync(exportsDir, true);
    }
    const zipPath: string =
      `${exportsDir}/tixing_backup_${DataPortabilityService.dateStamp()}_${Date.now() % 100000}.zip`;
    await DataPortabilityService.buildBundle(studentId, zipPath);
    DataPortabilityService.rotateExports(exportsDir);
    return zipPath;
  }

  /**
   * 先在应用缓存中生成备份包，再拉起系统保存窗口。
   * 用户选择目录/文件名后写入用户可见位置；取消保存时返回 undefined。
   */
  static async exportBundleToUserSelectedPath(studentId: string): Promise<string | undefined> {
    const ctx = AppContextHolder.require();
    const exportDir: string = ctx.cacheDir + '/export_to_user';
    if (!fs.accessSync(exportDir)) {
      fs.mkdirSync(exportDir, true);
    }
    const fileName: string =
      `tixing_backup_${DataPortabilityService.dateStamp()}_${Date.now() % 100000}.zip`;
    const zipPath: string = `${exportDir}/${fileName}`;
    try {
      await DataPortabilityService.buildBundle(studentId, zipPath);
      const targetUri: string | undefined = await DataPortabilityService.pickExportDestination(fileName);
      if (targetUri === undefined) {
        return undefined;
      }
      await DataPortabilityService.copyFileToUri(zipPath, targetUri);
      return targetUri;
    } finally {
      removeDirRecursive(exportDir);
    }
  }

  private static async buildBundle(studentId: string, zipPath: string): Promise<void> {
    const student: Student | undefined = await dbHelper.queryStudent(studentId);
    const mistakes: Mistake[] = await dbHelper.queryMistakesByStudent(studentId);
    const logs: ReviewLog[] = await dbHelper.queryReviewLogsByStudent(studentId);
    const settings: ReminderSettings = await dbHelper.queryReminderSettings(studentId);
    const voiceAsks: VoiceAskRecord[] = await dbHelper.queryVoiceAskRecords(studentId);
    const insights: InterestInsight[] = await dbHelper.queryInterestInsights(studentId, 100);
    const pointsLogs: PointsLog[] = await dbHelper.queryPointsLogs(studentId);
    const redemptions: RedemptionRecord[] = await dbHelper.queryRedemptions(studentId);
    const knowledgeProfiles: KnowledgeProfile[] = await dbHelper.queryKnowledgeProfiles(studentId);
    const analyticsEvents: AnalyticsEvent[] = await dbHelper.queryAnalyticsEvents();

    const ctx = AppContextHolder.require();
    const stagingDir: string = `${ctx.cacheDir}/export_staging_${Date.now()}`;
    const imagesDir: string = `${stagingDir}/images`;
    const notesDir: string = `${stagingDir}/notes`;
    const audioDir: string = `${stagingDir}/audio`;
    fs.mkdirSync(imagesDir, true);
    fs.mkdirSync(notesDir, true);
    fs.mkdirSync(audioDir, true);

    try {
      const manifest: BundleManifest = {
        app: BUNDLE_APP,
        version: BUNDLE_VERSION,
        exportedAt: Date.now(),
        studentId: studentId
      };
      DataPortabilityService.writeText(`${stagingDir}/manifest.json`, JSON.stringify(manifest));

      const studentExport: ExportStudent | undefined = student === undefined ? undefined : {
        id: student.id,
        parentId: student.parentId,
        nickname: student.nickname,
        grade: student.grade,
        textbookVersion: student.textbookVersion,
        region: student.region,
        school: student.school,
        communityBrowseEnabled: student.communityBrowseEnabled,
        communityShareEnabled: student.communityShareEnabled,
        createdAt: student.createdAt
      };

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
        if (m.notesAttachmentUrl.length > 0 && m.notesAttachmentUrl.startsWith(ownedDir)) {
          try {
            if (fs.accessSync(m.notesAttachmentUrl)) {
              fs.copyFileSync(m.notesAttachmentUrl, `${notesDir}/${m.id}.jpg`);
            }
          } catch (e) {
            PerformanceMonitor.warn('export copy note image failed: ' + m.id);
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
      const voiceArr: ExportVoiceAsk[] = [];
      const ownedAudioDir: string = ctx.filesDir + '/voice_asks';
      for (const record of voiceAsks) {
        const vr: ExportVoiceAsk = {
          id: record.id, studentId: record.studentId,
          questionText: record.questionText, answerText: record.answerText,
          subject: record.subject, topic: record.topic,
          interestTags: record.interestTags, questionType: record.questionType,
          gradeLevel: record.gradeLevel, audioPath: record.audioPath,
          audioDuration: record.audioDuration, asrStatus: record.asrStatus,
          aiStatus: record.aiStatus, safetyLevel: record.safetyLevel,
          status: record.status, createdAt: record.createdAt, updatedAt: record.updatedAt
        };
        voiceArr.push(vr);
        if (record.audioPath.length > 0 && record.audioPath.startsWith(ownedAudioDir)) {
          try {
            if (fs.accessSync(record.audioPath)) {
              fs.copyFileSync(record.audioPath,
                `${audioDir}/${record.id}${DataPortabilityService.audioExtension(record.audioPath)}`);
            }
          } catch (e) {
            PerformanceMonitor.warn('export copy voice audio failed: ' + record.id);
          }
        }
      }
      const insightArr: ExportInsight[] = [];
      for (const insight of insights) {
        const ei: ExportInsight = {
          id: insight.id, studentId: insight.studentId,
          periodStart: insight.periodStart, periodEnd: insight.periodEnd,
          questionCount: insight.questionCount, topSubjects: insight.topSubjects,
          topTopics: insight.topTopics, interestTags: insight.interestTags,
          trend: insight.trend, childSummary: insight.childSummary,
          parentSummary: insight.parentSummary,
          recommendedActivities: insight.recommendedActivities,
          generatedAt: insight.generatedAt
        };
        insightArr.push(ei);
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
      const pointsArr: ExportPointsLog[] = pointsLogs.map((log: PointsLog): ExportPointsLog => {
        return {
          id: log.id,
          studentId: log.studentId,
          actionType: log.actionType,
          points: log.points,
          createdAt: log.createdAt
        };
      });
      const redemptionArr: ExportRedemption[] = redemptions.map((record: RedemptionRecord): ExportRedemption => {
        return {
          id: record.id,
          studentId: record.studentId,
          itemId: record.itemId,
          cost: record.cost,
          redeemedAt: record.redeemedAt
        };
      });
      const knowledgeProfileArr: ExportKnowledgeProfile[] =
        knowledgeProfiles.map((profile: KnowledgeProfile): ExportKnowledgeProfile => {
          return {
            id: profile.id,
            studentId: profile.studentId,
            knowledgeTagId: profile.knowledgeTagId,
            totalMistakes: profile.totalMistakes,
            masteredCount: profile.masteredCount,
            currentMasteryScore: profile.currentMasteryScore,
            trend: profile.trend,
            updatedAt: profile.updatedAt
          };
        });
      const analyticsArr: ExportAnalyticsEvent[] =
        analyticsEvents.map((event: AnalyticsEvent): ExportAnalyticsEvent => {
          return {
            id: event.id,
            eventType: event.eventType,
            studentIdHash: event.studentIdHash,
            platform: event.platform,
            properties: event.properties,
            occurredAt: event.occurredAt
          };
        });
      const dataRoot: ExportDataRoot = {
        student: studentExport,
        mistakes: mistakesArr,
        reviewLogs: logsArr,
        settings: settingsExport,
        voiceAsks: voiceArr,
        interestInsights: insightArr,
        pointsLogs: pointsArr,
        redemptions: redemptionArr,
        knowledgeProfiles: knowledgeProfileArr,
        analyticsEvents: analyticsArr
      };
      DataPortabilityService.writeText(`${stagingDir}/data.json`, JSON.stringify(dataRoot));

      const zlibOpts: zlib.Options = {};
      await zlib.compressFile(stagingDir, zipPath, zlibOpts);
      if (!fs.accessSync(zipPath)) {
        throw new Error('压缩产物写入失败');
      }
    } finally {
      removeDirRecursive(stagingDir);
    }
  }

  /** 拉起系统保存文件窗口，让用户选择备份文件的保存位置与文件名。 */
  private static async pickExportDestination(fileName: string): Promise<string | undefined> {
    const docPicker = new picker.DocumentViewPicker(AppContextHolder.require());
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    options.fileSuffixChoices = ['.zip'];
    const uris: string[] = await docPicker.save(options);
    return uris.length > 0 ? uris[0] : undefined;
  }

  private static async copyFileToUri(sourcePath: string, targetUri: string): Promise<void> {
    const srcFile = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY);
    let destFile: fs.File | undefined = undefined;
    try {
      destFile = fs.openSync(targetUri, fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      await fs.copyFile(srcFile.fd, destFile.fd);
    } catch (e) {
      PerformanceMonitor.warn('copy export bundle to user path failed');
      throw new Error('备份文件写入所选位置失败，请重试');
    } finally {
      if (destFile !== undefined) {
        fs.closeSync(destFile);
      }
      fs.closeSync(srcFile);
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
      throw new Error(`备份文件超过 100MB 上限（当前 ${Math.round(stat.size / 1024 / 1024)}MB），请精简后重试`);
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
    preview.voiceAskCount = summary.voiceAskCount;
    preview.insightCount = summary.insightCount;
    preview.audioCount = summary.audioCount;
    preview.pointsLogCount = summary.pointsLogCount;
    preview.redemptionCount = summary.redemptionCount;
    preview.knowledgeProfileCount = summary.knowledgeProfileCount;
    preview.analyticsEventCount = summary.analyticsEventCount;
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
    const voiceItems: VoiceBundlePreviewItem[] = [];
    for (const raw of summary.voicePreview) {
      const item = new VoiceBundlePreviewItem();
      item.id = raw.id;
      item.questionText = raw.questionText !== undefined ? raw.questionText : '';
      item.subject = raw.subject !== undefined ? raw.subject : '';
      item.createdAt = raw.createdAt;
      voiceItems.push(item);
    }
    preview.voicePreviewItems = voiceItems;
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

    const mistakes: Mistake[] = DataPortabilityService.toMistakes(
      data.mistakes !== undefined ? data.mistakes : []);
    const logs: ReviewLog[] = DataPortabilityService.toLogs(
      data.reviewLogs !== undefined ? data.reviewLogs : []);
    const voiceAsks: VoiceAskRecord[] = DataPortabilityService.toVoiceAsks(
      data.voiceAsks !== undefined ? data.voiceAsks : []);
    const insights: InterestInsight[] = DataPortabilityService.toInsights(
      data.interestInsights !== undefined ? data.interestInsights : []);
    const pointsLogs: PointsLog[] = DataPortabilityService.toPointsLogs(
      data.pointsLogs !== undefined ? data.pointsLogs : []);
    const redemptions: RedemptionRecord[] = DataPortabilityService.toRedemptions(
      data.redemptions !== undefined ? data.redemptions : []);
    const knowledgeProfiles: KnowledgeProfile[] = DataPortabilityService.toKnowledgeProfiles(
      data.knowledgeProfiles !== undefined ? data.knowledgeProfiles : []);
    const analyticsEvents: AnalyticsEvent[] = DataPortabilityService.toAnalyticsEvents(
      data.analyticsEvents !== undefined ? data.analyticsEvents : []);

    // 图片回填：包内图片拷贝到本机错题目录，并替换 imageUrl 为本机路径
    const ownedDir: string = ctx.filesDir + '/mistakes';
    if (!fs.accessSync(ownedDir)) {
      fs.mkdirSync(ownedDir, true);
    }
    for (const m of mistakes) {
      const bundledImage: string = `${preview.bundleRoot}/images/${m.id}.jpg`;
      const bundledNote: string = `${preview.bundleRoot}/notes/${m.id}.jpg`;
      try {
        if (fs.accessSync(bundledImage)) {
          const destPath: string = `${ownedDir}/import_${m.id}.jpg`;
          fs.copyFileSync(bundledImage, destPath);
          m.imageUrl = destPath;
        }
        if (fs.accessSync(bundledNote)) {
          const notePath: string = `${ownedDir}/import_note_${m.id}.jpg`;
          fs.copyFileSync(bundledNote, notePath);
          m.notesAttachmentUrl = notePath;
        }
      } catch (e) {
        PerformanceMonitor.warn('import copy image failed: ' + m.id);
      }
    }

    // 原始录音随包迁移：导入后仍保存在应用沙箱，可随时回听。
    const ownedAudioDir: string = ctx.filesDir + '/voice_asks';
    if (!fs.accessSync(ownedAudioDir)) {
      fs.mkdirSync(ownedAudioDir, true);
    }
    for (const record of voiceAsks) {
      const bundledWav: string = `${preview.bundleRoot}/audio/${record.id}.wav`;
      const bundledMp3: string = `${preview.bundleRoot}/audio/${record.id}.mp3`;
      const bundledAudio: string = fs.accessSync(bundledWav) ? bundledWav : bundledMp3;
      const audioExtension: string = bundledAudio === bundledWav ? '.wav' : '.mp3';
      try {
        if (fs.accessSync(bundledAudio)) {
          const destPath: string = `${ownedAudioDir}/import_${record.id}${audioExtension}`;
          fs.copyFileSync(bundledAudio, destPath);
          record.audioPath = destPath;
        }
      } catch (e) {
        PerformanceMonitor.warn('import copy voice audio failed: ' + record.id);
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
      for (const record of voiceAsks) {
        const existingVoice: VoiceAskRecord | undefined = await dbHelper.queryVoiceAskRecordById(record.id);
        if (existingVoice === undefined) {
          const res: DbResult = await dbHelper.insertVoiceAskRecord(record);
          if (!res.success) {
            return res;
          }
        }
      }
      const existingInsights: InterestInsight[] = await dbHelper.queryInterestInsights('stu_default', 1000);
      for (const insight of insights) {
        const duplicate: boolean = existingInsights.some((item: InterestInsight): boolean => item.id === insight.id);
        if (!duplicate) {
          const res: DbResult = await dbHelper.insertInterestInsight(insight);
          if (!res.success) {
            return res;
          }
        }
      }
      for (const log of pointsLogs) {
        if (!(await dbHelper.hasPointsLog(log.id))) {
          const res: DbResult = await dbHelper.insertPointsLog(log);
          if (!res.success) {
            return res;
          }
        }
      }
      const existingRedemptions: RedemptionRecord[] = await dbHelper.queryRedemptions('stu_default');
      for (const record of redemptions) {
        if (!existingRedemptions.some((item: RedemptionRecord): boolean => item.id === record.id)) {
          const res: DbResult = await dbHelper.importRedemption(record);
          if (!res.success) {
            return res;
          }
        }
      }
      for (const event of analyticsEvents) {
        if (!(await dbHelper.hasAnalyticsEvent(event.id))) {
          const res: DbResult = await dbHelper.insertAnalyticsEvent(event);
          if (!res.success) {
            return res;
          }
        }
      }
      PerformanceMonitor.writeStatistic('import_bundle', {
        'inserted': inserted,
        'logs': logs.length,
        'points': pointsLogs.length,
        'redemptions': redemptions.length,
        'analytics': analyticsEvents.length
      });
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

    if (data.student !== undefined) {
      await dbHelper.upsertStudent(DataPortabilityService.toStudent(data.student));
    }

    if (knowledgeProfiles.length > 0) {
      await dbHelper.upsertKnowledgeProfiles(knowledgeProfiles);
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
      m.studentId = 'stu_default';
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

  private static toVoiceAsks(arr: ExportVoiceAsk[]): VoiceAskRecord[] {
    const list: VoiceAskRecord[] = [];
    for (const raw of arr) {
      const record = new VoiceAskRecord();
      record.id = raw.id;
      record.studentId = 'stu_default';
      record.questionText = raw.questionText !== undefined ? raw.questionText : '';
      record.answerText = raw.answerText !== undefined ? raw.answerText : '';
      record.subject = raw.subject !== undefined ? raw.subject : 'other';
      record.topic = raw.topic !== undefined ? raw.topic : '';
      record.interestTags = raw.interestTags !== undefined ? raw.interestTags : [];
      record.questionType = raw.questionType !== undefined ? raw.questionType : 'fact';
      record.gradeLevel = raw.gradeLevel !== undefined ? raw.gradeLevel : '';
      record.audioPath = raw.audioPath !== undefined ? raw.audioPath : '';
      record.audioDuration = raw.audioDuration !== undefined ? raw.audioDuration : 0;
      record.asrStatus = raw.asrStatus !== undefined ? raw.asrStatus : 'done';
      record.aiStatus = raw.aiStatus !== undefined ? raw.aiStatus : 'done';
      record.safetyLevel = raw.safetyLevel !== undefined ? raw.safetyLevel : 'normal';
      record.status = raw.status !== undefined ? raw.status : 'active';
      record.createdAt = raw.createdAt !== undefined ? raw.createdAt : Date.now();
      record.updatedAt = raw.updatedAt !== undefined ? raw.updatedAt : record.createdAt;
      list.push(record);
    }
    return list;
  }

  private static toInsights(arr: ExportInsight[]): InterestInsight[] {
    const list: InterestInsight[] = [];
    for (const raw of arr) {
      const insight = new InterestInsight();
      insight.id = raw.id;
      insight.studentId = 'stu_default';
      insight.periodStart = raw.periodStart !== undefined ? raw.periodStart : 0;
      insight.periodEnd = raw.periodEnd !== undefined ? raw.periodEnd : Date.now();
      insight.questionCount = raw.questionCount !== undefined ? raw.questionCount : 0;
      insight.topSubjects = raw.topSubjects !== undefined ? raw.topSubjects : [];
      insight.topTopics = raw.topTopics !== undefined ? raw.topTopics : [];
      insight.interestTags = raw.interestTags !== undefined ? raw.interestTags : [];
      insight.trend = raw.trend !== undefined ? raw.trend : 'stable';
      insight.childSummary = raw.childSummary !== undefined ? raw.childSummary : '';
      insight.parentSummary = raw.parentSummary !== undefined ? raw.parentSummary : '';
      insight.recommendedActivities = raw.recommendedActivities !== undefined
        ? raw.recommendedActivities : [];
      insight.generatedAt = raw.generatedAt !== undefined ? raw.generatedAt : Date.now();
      list.push(insight);
    }
    return list;
  }

  private static toStudent(raw: ExportStudent): Student {
    const student = new Student();
    // 单学生应用固定读取 stu_default；导入时恢复资料内容，但统一挂到本机活跃学生。
    student.id = 'stu_default';
    student.parentId = raw.parentId !== undefined ? raw.parentId : '';
    student.nickname = raw.nickname !== undefined ? raw.nickname : '';
    student.grade = raw.grade as Grade;
    student.textbookVersion = raw.textbookVersion as TextbookVersion;
    student.region = raw.region !== undefined ? raw.region : '';
    student.school = raw.school !== undefined ? raw.school : '';
    student.communityBrowseEnabled = raw.communityBrowseEnabled === true;
    student.communityShareEnabled = raw.communityShareEnabled === true;
    student.createdAt = raw.createdAt !== undefined ? raw.createdAt : Date.now();
    return student;
  }

  private static toPointsLogs(arr: ExportPointsLog[]): PointsLog[] {
    const list: PointsLog[] = [];
    for (const raw of arr) {
      const log = new PointsLog();
      log.id = raw.id;
      log.studentId = 'stu_default';
      log.actionType = raw.actionType as PointsActionType;
      log.points = raw.points !== undefined ? raw.points : 0;
      log.createdAt = raw.createdAt !== undefined ? raw.createdAt : Date.now();
      list.push(log);
    }
    return list;
  }

  private static toRedemptions(arr: ExportRedemption[]): RedemptionRecord[] {
    const list: RedemptionRecord[] = [];
    for (const raw of arr) {
      const record = new RedemptionRecord();
      record.id = raw.id;
      record.studentId = 'stu_default';
      record.itemId = raw.itemId !== undefined ? raw.itemId : '';
      record.cost = raw.cost !== undefined ? raw.cost : 0;
      record.redeemedAt = raw.redeemedAt !== undefined ? raw.redeemedAt : Date.now();
      list.push(record);
    }
    return list;
  }

  private static toKnowledgeProfiles(arr: ExportKnowledgeProfile[]): KnowledgeProfile[] {
    const list: KnowledgeProfile[] = [];
    for (const raw of arr) {
      const profile = new KnowledgeProfile();
      profile.id = raw.id;
      profile.studentId = 'stu_default';
      profile.knowledgeTagId = raw.knowledgeTagId !== undefined ? raw.knowledgeTagId : '';
      profile.totalMistakes = raw.totalMistakes !== undefined ? raw.totalMistakes : 0;
      profile.masteredCount = raw.masteredCount !== undefined ? raw.masteredCount : 0;
      profile.currentMasteryScore = raw.currentMasteryScore !== undefined ? raw.currentMasteryScore : 0;
      profile.trend = raw.trend as Trend;
      profile.updatedAt = raw.updatedAt !== undefined ? raw.updatedAt : Date.now();
      list.push(profile);
    }
    return list;
  }

  private static toAnalyticsEvents(arr: ExportAnalyticsEvent[]): AnalyticsEvent[] {
    const list: AnalyticsEvent[] = [];
    for (const raw of arr) {
      const event = new AnalyticsEvent();
      event.id = raw.id;
      event.eventType = raw.eventType !== undefined ? raw.eventType : '';
      event.studentIdHash = raw.studentIdHash !== undefined ? raw.studentIdHash : '';
      event.platform = raw.platform !== undefined && raw.platform.length > 0 ? raw.platform : 'harmonyos';
      event.properties = raw.properties !== undefined ? raw.properties : '{}';
      event.occurredAt = raw.occurredAt !== undefined ? raw.occurredAt : Date.now();
      list.push(event);
    }
    return list;
  }

  private static audioExtension(path: string): string {
    if (path.endsWith('.mp3')) {
      return '.mp3';
    }
    return '.wav';
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
