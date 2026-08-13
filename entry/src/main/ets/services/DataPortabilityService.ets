import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import util from '@ohos.util';
import { Mistake } from '../models/Mistake';
import { ReviewLog } from '../models/ReviewLog';
import { Subject, ErrorType, MistakeStatus, AnswerType } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { AppContextHolder } from '../common/AppContext';

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
}

interface ExportRoot {
  app: string;
  version: number;
  exportedAt: number;
  mistakes: ExportMistake[];
  reviewLogs: ExportLog[];
}

export class ExportData {
  mistakes: Mistake[] = [];
  reviewLogs: ReviewLog[] = [];
  exportedAt: number = 0;
}

export class ImportPreview {
  mistakes: Mistake[] = [];
  logCount: number = 0;
}

export class DataPortabilityService {
  static async exportToJson(_studentId: string): Promise<string> {
    const mistakes: Mistake[] = await dbHelper.queryMistakes();
    const allLogs: ReviewLog[] = [];
    for (const m of mistakes) {
      const logs: ReviewLog[] = await dbHelper.queryReviewLogs(m.id);
      for (const l of logs) {
        allLogs.push(l);
      }
    }

    const mistakesArr: ExportMistake[] = [];
    for (const m of mistakes) {
      const em: ExportMistake = {
        id: m.id, studentId: m.studentId, imageUrl: m.imageUrl,
        ocrText: m.ocrText, ocrConfidence: m.ocrConfidence,
        isConfirmed: m.isConfirmed, subject: m.subject,
        knowledgeTagIds: m.knowledgeTagIds, errorType: m.errorType,
        status: m.status, intervalIndex: m.intervalIndex,
        nextReviewDate: m.nextReviewDate, firstReviewDuration: m.firstReviewDuration,
        standardAnswer: m.standardAnswer, answerType: m.answerType,
        notes: m.notes, notesAttachmentUrl: m.notesAttachmentUrl,
        createdAt: m.createdAt
      };
      mistakesArr.push(em);
    }
    const logsArr: ExportLog[] = [];
    for (const l of allLogs) {
      const el: ExportLog = {
        id: l.id, mistakeId: l.mistakeId, reviewTime: l.reviewTime,
        gradingMethod: l.gradingMethod, inputMethod: l.inputMethod,
        correct: l.correct, durationSeconds: l.durationSeconds,
        pointsAwarded: l.pointsAwarded
      };
      logsArr.push(el);
    }
    const root: ExportRoot = {
      app: 'tixing', version: 1, exportedAt: Date.now(),
      mistakes: mistakesArr, reviewLogs: logsArr
    };

    const ctx = AppContextHolder.require();
    const dir: string = ctx.filesDir + '/exports';
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
    const path: string = `${dir}/tixing_export_${DataPortabilityService.dateStamp()}.json`;
    const json: string = JSON.stringify(root);
    const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    fs.writeSync(file.fd, json);
    fs.closeSync(file);
    return path;
  }

  static async pickImportFile(): Promise<string | undefined> {
    try {
      const docPicker = new picker.DocumentViewPicker();
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['.json'];
      const uris: string[] = await docPicker.select(options);
      if (uris.length === 0) {
        return undefined;
      }
      return DataPortabilityService.copyToCache(uris[0]);
    } catch (e) {
      return undefined;
    }
  }

  static parsePreview(path: string): ImportPreview {
    const preview = new ImportPreview();
    try {
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(path);
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      const text: string = DataPortabilityService.decode(buffer);
      const root = JSON.parse(text) as ExportRoot;
      preview.mistakes = DataPortabilityService.toMistakes(root.mistakes);
      preview.logCount = root.reviewLogs.length;
    } catch (e) {
    }
    return preview;
  }

  static async applyImport(preview: ImportPreview): Promise<number> {
    let count: number = 0;
    for (const m of preview.mistakes) {
      const existing = await dbHelper.queryMistakeById(m.id);
      if (existing === undefined) {
        await dbHelper.insertMistake(m);
        count++;
      }
    }
    return count;
  }

  private static toMistakes(arr: ExportMistake[]): Mistake[] {
    const list: Mistake[] = [];
    for (const em of arr) {
      const m = new Mistake();
      m.id = em.id;
      m.studentId = em.studentId;
      m.imageUrl = em.imageUrl;
      m.ocrText = em.ocrText;
      m.ocrConfidence = em.ocrConfidence;
      m.isConfirmed = em.isConfirmed;
      m.subject = em.subject as Subject;
      m.errorType = em.errorType as ErrorType;
      m.status = em.status as MistakeStatus;
      m.intervalIndex = em.intervalIndex;
      m.nextReviewDate = em.nextReviewDate;
      m.firstReviewDuration = em.firstReviewDuration;
      m.standardAnswer = em.standardAnswer;
      m.answerType = em.answerType as AnswerType;
      m.notes = em.notes;
      m.notesAttachmentUrl = em.notesAttachmentUrl;
      m.createdAt = em.createdAt;
      m.knowledgeTagIds = em.knowledgeTagIds;
      list.push(m);
    }
    return list;
  }

  private static copyToCache(uri: string): string {
    const ctx = AppContextHolder.require();
    const dir: string = ctx.cacheDir + '/imports';
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
    const dest: string = `${dir}/import_${Date.now()}.json`;
    const srcFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    const destFile = fs.openSync(dest, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    fs.copyFileSync(srcFile.fd, destFile.fd);
    fs.closeSync(srcFile);
    fs.closeSync(destFile);
    return dest;
  }

  private static decode(buffer: ArrayBuffer): string {
    const textDecoder = util.TextDecoder.create('utf-8');
    return textDecoder.decodeToString(new Uint8Array(buffer));
  }

  private static dateStamp(): string {
    const d = new Date();
    const m: number = d.getMonth() + 1;
    const day: number = d.getDate();
    return `${d.getFullYear()}${m < 10 ? '0' + m : m}${day < 10 ? '0' + day : day}`;
  }
}
