import { relationalStore } from '@kit.ArkData';
import { Mistake } from '../models/Mistake';
import { ReviewLog } from '../models/ReviewLog';
import { KnowledgeTag, KnowledgeProfile } from '../models/KnowledgeTag';
import { Student, ParentAccount } from '../models/Student';
import { PointsLog, PointsSummary } from '../models/PointsLog';
import { CommunityPost } from '../models/CommunityPost';
import { ReminderSettings } from '../models/ReminderSettings';
import { AnalyticsEvent, MetricSummary } from '../models/AnalyticsEvent';
import {
  Subject, Grade, ErrorType, MistakeStatus, AnswerType, GradingMethod,
  InputMethod, SyncStatus, PointsActionType, CommunityPostStatus,
  TextbookVersion, Trend, SubscriptionStatus
} from '../models/Enums';

const DB_NAME: string = 'tixing.db';
const DB_VERSION: number = 1;

const CREATE_MISTAKE_TABLE: string =
  `CREATE TABLE IF NOT EXISTS mistake (
    id TEXT PRIMARY KEY, studentId TEXT, imageUrl TEXT, ocrText TEXT,
    ocrConfidence REAL, isConfirmed INTEGER, subject TEXT, knowledgeTagIds TEXT,
    errorType TEXT, status TEXT, intervalIndex INTEGER, nextReviewDate INTEGER,
    firstReviewDuration INTEGER, standardAnswer TEXT, answerType TEXT,
    notes TEXT, notesAttachmentUrl TEXT, sharedToCommunity INTEGER,
    communityPostId TEXT, createdAt INTEGER, syncStatus TEXT)`;

const CREATE_REVIEW_LOG_TABLE: string =
  `CREATE TABLE IF NOT EXISTS review_log (
    id TEXT PRIMARY KEY, mistakeId TEXT, reviewTime INTEGER,
    gradingMethod TEXT, inputMethod TEXT, correct INTEGER,
    durationSeconds INTEGER, pointsAwarded INTEGER, clientOperationId TEXT)`;

const CREATE_KNOWLEDGE_TAG_TABLE: string =
  `CREATE TABLE IF NOT EXISTS knowledge_tag (
    id TEXT PRIMARY KEY, subject TEXT, grade TEXT, textbookVersion TEXT,
    name TEXT, parentTagId TEXT)`;

const CREATE_KNOWLEDGE_PROFILE_TABLE: string =
  `CREATE TABLE IF NOT EXISTS knowledge_profile (
    id TEXT PRIMARY KEY, studentId TEXT, knowledgeTagId TEXT,
    totalMistakes INTEGER, masteredCount INTEGER, currentMasteryScore REAL,
    trend TEXT, updatedAt INTEGER)`;

const CREATE_STUDENT_TABLE: string =
  `CREATE TABLE IF NOT EXISTS student (
    id TEXT PRIMARY KEY, parentId TEXT, nickname TEXT, grade TEXT,
    textbookVersion TEXT, region TEXT, school TEXT,
    communityBrowseEnabled INTEGER, communityShareEnabled INTEGER, createdAt INTEGER)`;

const CREATE_PARENT_TABLE: string =
  `CREATE TABLE IF NOT EXISTS parent_account (
    id TEXT PRIMARY KEY, phoneHash TEXT, subscriptionStatus TEXT, createdAt INTEGER)`;

const CREATE_POINTS_LOG_TABLE: string =
  `CREATE TABLE IF NOT EXISTS points_log (
    id TEXT PRIMARY KEY, studentId TEXT, actionType TEXT,
    points INTEGER, createdAt INTEGER)`;

const CREATE_COMMUNITY_POST_TABLE: string =
  `CREATE TABLE IF NOT EXISTS community_post (
    id TEXT PRIMARY KEY, studentId TEXT, mistakeId TEXT,
    redactedImageUrl TEXT, knowledgeTagId TEXT, grade TEXT,
    status TEXT, parentConfirmedAt INTEGER, likeCount INTEGER,
    collectCount INTEGER, createdAt INTEGER)`;

const CREATE_REMINDER_SETTINGS_TABLE: string =
  `CREATE TABLE IF NOT EXISTS reminder_settings (
    id TEXT PRIMARY KEY, studentId TEXT, reviewTimeStart TEXT,
    reviewTimeEnd TEXT, dailyLimit INTEGER, mathEnabled INTEGER,
    chineseEnabled INTEGER, englishEnabled INTEGER, scienceEnabled INTEGER,
    doNotDisturb INTEGER, notificationEnabled INTEGER, updatedAt INTEGER)`;

const CREATE_ANALYTICS_EVENT_TABLE: string =
  `CREATE TABLE IF NOT EXISTS analytics_event (
    id TEXT PRIMARY KEY, eventType TEXT, studentIdHash TEXT,
    platform TEXT, properties TEXT, occurredAt INTEGER)`;

const CREATE_REDEMPTION_TABLE: string =
  `CREATE TABLE IF NOT EXISTS redemption (
    id TEXT PRIMARY KEY, studentId TEXT, itemId TEXT, cost INTEGER, redeemedAt INTEGER)`;

export class DatabaseHelper {
  private rdbStore: relationalStore.RdbStore | undefined = undefined;

  async init(context: Context): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.rdbStore = await relationalStore.getRdbStore(context, config);
    await this.rdbStore.executeSql(CREATE_MISTAKE_TABLE);
    await this.rdbStore.executeSql(CREATE_REVIEW_LOG_TABLE);
    await this.rdbStore.executeSql(CREATE_KNOWLEDGE_TAG_TABLE);
    await this.rdbStore.executeSql(CREATE_KNOWLEDGE_PROFILE_TABLE);
    await this.rdbStore.executeSql(CREATE_STUDENT_TABLE);
    await this.rdbStore.executeSql(CREATE_PARENT_TABLE);
    await this.rdbStore.executeSql(CREATE_POINTS_LOG_TABLE);
    await this.rdbStore.executeSql(CREATE_COMMUNITY_POST_TABLE);
    await this.rdbStore.executeSql(CREATE_REMINDER_SETTINGS_TABLE);
    await this.rdbStore.executeSql(CREATE_ANALYTICS_EVENT_TABLE);
    await this.rdbStore.executeSql(CREATE_REDEMPTION_TABLE);
    await this.seedKnowledgeTags();
  }

  private async seedKnowledgeTags(): Promise<void> {
    if (this.rdbStore === undefined) {
      return;
    }
    const existing = await this.queryKnowledgeTags();
    if (existing.length > 0) {
      return;
    }
    const seeds: KnowledgeTag[] = [
      this.makeTag('kt_g3_math_01', Subject.MATH, Grade.G3, TextbookVersion.PEP, '加法与减法', ''),
      this.makeTag('kt_g3_math_02', Subject.MATH, Grade.G3, TextbookVersion.PEP, '乘法与除法', ''),
      this.makeTag('kt_g3_math_03', Subject.MATH, Grade.G3, TextbookVersion.PEP, '分数初步', ''),
      this.makeTag('kt_g4_math_01', Subject.MATH, Grade.G4, TextbookVersion.PEP, '多位数运算', ''),
      this.makeTag('kt_g4_math_02', Subject.MATH, Grade.G4, TextbookVersion.PEP, '小数认识', ''),
      this.makeTag('kt_g5_math_01', Subject.MATH, Grade.G5, TextbookVersion.PEP, '方程与代数', ''),
      this.makeTag('kt_g5_math_02', Subject.MATH, Grade.G5, TextbookVersion.PEP, '分数运算', ''),
      this.makeTag('kt_g6_math_01', Subject.MATH, Grade.G6, TextbookVersion.PEP, '比例与百分数', ''),
      this.makeTag('kt_g3_chinese_01', Subject.CHINESE, Grade.G3, TextbookVersion.PEP, '字词理解', ''),
      this.makeTag('kt_g3_chinese_02', Subject.CHINESE, Grade.G3, TextbookVersion.PEP, '阅读理解', ''),
      this.makeTag('kt_g4_chinese_01', Subject.CHINESE, Grade.G4, TextbookVersion.PEP, '段落分析', ''),
      this.makeTag('kt_g4_chinese_02', Subject.CHINESE, Grade.G4, TextbookVersion.PEP, '作文基础', ''),
    ];
    for (const tag of seeds) {
      await this.insertKnowledgeTag(tag);
    }
  }

  private makeTag(id: string, subject: Subject, grade: Grade, ver: TextbookVersion, name: string, parent: string): KnowledgeTag {
    const t = new KnowledgeTag();
    t.id = id;
    t.subject = subject;
    t.grade = grade;
    t.textbookVersion = ver;
    t.name = name;
    t.parentTagId = parent;
    return t;
  }

  getStore(): relationalStore.RdbStore | undefined {
    return this.rdbStore;
  }

  async insertMistake(m: Mistake): Promise<void> {
    if (this.rdbStore === undefined) return;
    const value: Record<string, relationalStore.ValueType> = {
      'id': m.id, 'studentId': m.studentId, 'imageUrl': m.imageUrl,
      'ocrText': m.ocrText, 'ocrConfidence': m.ocrConfidence,
      'isConfirmed': m.isConfirmed ? 1 : 0, 'subject': m.subject,
      'knowledgeTagIds': m.knowledgeTagIds.join(','),
      'errorType': m.errorType, 'status': m.status,
      'intervalIndex': m.intervalIndex, 'nextReviewDate': m.nextReviewDate,
      'firstReviewDuration': m.firstReviewDuration,
      'standardAnswer': m.standardAnswer, 'answerType': m.answerType,
      'notes': m.notes, 'notesAttachmentUrl': m.notesAttachmentUrl,
      'sharedToCommunity': m.sharedToCommunity ? 1 : 0,
      'communityPostId': m.communityPostId, 'createdAt': m.createdAt,
      'syncStatus': m.syncStatus
    };
    await this.rdbStore.insert('mistake', value);
  }

  async updateMistake(m: Mistake): Promise<void> {
    if (this.rdbStore === undefined) return;
    const value: Record<string, relationalStore.ValueType> = {
      'ocrText': m.ocrText, 'ocrConfidence': m.ocrConfidence,
      'isConfirmed': m.isConfirmed ? 1 : 0, 'subject': m.subject,
      'knowledgeTagIds': m.knowledgeTagIds.join(','),
      'errorType': m.errorType, 'status': m.status,
      'intervalIndex': m.intervalIndex, 'nextReviewDate': m.nextReviewDate,
      'firstReviewDuration': m.firstReviewDuration,
      'standardAnswer': m.standardAnswer, 'answerType': m.answerType,
      'notes': m.notes, 'notesAttachmentUrl': m.notesAttachmentUrl,
      'syncStatus': m.syncStatus
    };
    const predicates = new relationalStore.RdbPredicates('mistake');
    predicates.equalTo('id', m.id);
    await this.rdbStore.update(value, predicates);
  }

  async queryMistakes(subject?: Subject, status?: MistakeStatus, keyword?: string, errorType?: ErrorType): Promise<Mistake[]> {
    if (this.rdbStore === undefined) return [];
    const predicates = new relationalStore.RdbPredicates('mistake');
    predicates.orderByDesc('createdAt');
    if (subject !== undefined) {
      predicates.equalTo('subject', subject);
    }
    if (status !== undefined) {
      predicates.equalTo('status', status);
    }
    if (errorType !== undefined) {
      predicates.equalTo('errorType', errorType);
    }
    if (keyword !== undefined && keyword.length > 0) {
      predicates.and();
      predicates.contains('ocrText', keyword);
    }
    const resultSet = await this.rdbStore.query(predicates);
    const list: Mistake[] = [];
    while (resultSet.goToNextRow()) {
      list.push(this.rowToMistake(resultSet));
    }
    resultSet.close();
    return list;
  }

  async queryMistakeById(id: string): Promise<Mistake | undefined> {
    if (this.rdbStore === undefined) return undefined;
    const predicates = new relationalStore.RdbPredicates('mistake');
    predicates.equalTo('id', id);
    const resultSet = await this.rdbStore.query(predicates);
    if (resultSet.goToFirstRow()) {
      const m = this.rowToMistake(resultSet);
      resultSet.close();
      return m;
    }
    resultSet.close();
    return undefined;
  }

  async queryTodayReviewMistakes(): Promise<Mistake[]> {
    if (this.rdbStore === undefined) return [];
    const now = Date.now();
    const predicates = new relationalStore.RdbPredicates('mistake');
    predicates.lessThanOrEqualTo('nextReviewDate', now);
    predicates.notEqualTo('status', MistakeStatus.MASTERED);
    predicates.orderByAsc('nextReviewDate');
    const resultSet = await this.rdbStore.query(predicates);
    const list: Mistake[] = [];
    while (resultSet.goToNextRow()) {
      list.push(this.rowToMistake(resultSet));
    }
    resultSet.close();
    return list;
  }

  private rowToMistake(rs: relationalStore.ResultSet): Mistake {
    const m = new Mistake();
    m.id = rs.getString(rs.getColumnIndex('id'));
    m.studentId = rs.getString(rs.getColumnIndex('studentId'));
    m.imageUrl = rs.getString(rs.getColumnIndex('imageUrl'));
    m.ocrText = rs.getString(rs.getColumnIndex('ocrText'));
    m.ocrConfidence = rs.getDouble(rs.getColumnIndex('ocrConfidence'));
    m.isConfirmed = rs.getLong(rs.getColumnIndex('isConfirmed')) === 1;
    m.subject = rs.getString(rs.getColumnIndex('subject')) as Subject;
    const tagStr = rs.getString(rs.getColumnIndex('knowledgeTagIds'));
    m.knowledgeTagIds = tagStr.length > 0 ? tagStr.split(',') : [];
    m.errorType = rs.getString(rs.getColumnIndex('errorType')) as ErrorType;
    m.status = rs.getString(rs.getColumnIndex('status')) as MistakeStatus;
    m.intervalIndex = rs.getLong(rs.getColumnIndex('intervalIndex'));
    m.nextReviewDate = rs.getLong(rs.getColumnIndex('nextReviewDate'));
    m.firstReviewDuration = rs.getLong(rs.getColumnIndex('firstReviewDuration'));
    m.standardAnswer = rs.getString(rs.getColumnIndex('standardAnswer'));
    m.answerType = rs.getString(rs.getColumnIndex('answerType')) as AnswerType;
    m.notes = rs.getString(rs.getColumnIndex('notes'));
    m.notesAttachmentUrl = rs.getString(rs.getColumnIndex('notesAttachmentUrl'));
    m.sharedToCommunity = rs.getLong(rs.getColumnIndex('sharedToCommunity')) === 1;
    m.communityPostId = rs.getString(rs.getColumnIndex('communityPostId'));
    m.createdAt = rs.getLong(rs.getColumnIndex('createdAt'));
    m.syncStatus = rs.getString(rs.getColumnIndex('syncStatus')) as SyncStatus;
    return m;
  }

  async insertReviewLog(log: ReviewLog): Promise<void> {
    if (this.rdbStore === undefined) return;
    const value: Record<string, relationalStore.ValueType> = {
      'id': log.id, 'mistakeId': log.mistakeId, 'reviewTime': log.reviewTime,
      'gradingMethod': log.gradingMethod, 'inputMethod': log.inputMethod,
      'correct': log.correct ? 1 : 0, 'durationSeconds': log.durationSeconds,
      'pointsAwarded': log.pointsAwarded, 'clientOperationId': log.clientOperationId
    };
    await this.rdbStore.insert('review_log', value);
  }

  async queryReviewLogs(mistakeId: string): Promise<ReviewLog[]> {
    if (this.rdbStore === undefined) return [];
    const predicates = new relationalStore.RdbPredicates('review_log');
    predicates.equalTo('mistakeId', mistakeId);
    predicates.orderByDesc('reviewTime');
    const resultSet = await this.rdbStore.query(predicates);
    const list: ReviewLog[] = [];
    while (resultSet.goToNextRow()) {
      const log = new ReviewLog();
      log.id = rs_col(resultSet, 'id');
      log.mistakeId = rs_col(resultSet, 'mistakeId');
      log.reviewTime = rs_col_long(resultSet, 'reviewTime');
      log.gradingMethod = rs_col(resultSet, 'gradingMethod') as GradingMethod;
      log.inputMethod = rs_col(resultSet, 'inputMethod') as InputMethod;
      log.correct = rs_col_long(resultSet, 'correct') === 1;
      log.durationSeconds = rs_col_long(resultSet, 'durationSeconds');
      log.pointsAwarded = rs_col_long(resultSet, 'pointsAwarded');
      log.clientOperationId = rs_col(resultSet, 'clientOperationId');
      list.push(log);
    }
    resultSet.close();
    return list;
  }

  async insertKnowledgeTag(tag: KnowledgeTag): Promise<void> {
    if (this.rdbStore === undefined) return;
    const value: Record<string, relationalStore.ValueType> = {
      'id': tag.id, 'subject': tag.subject, 'grade': tag.grade,
      'textbookVersion': tag.textbookVersion, 'name': tag.name,
      'parentTagId': tag.parentTagId
    };
    await this.rdbStore.insert('knowledge_tag', value);
  }

  async queryKnowledgeTags(subject?: Subject, grade?: Grade): Promise<KnowledgeTag[]> {
    if (this.rdbStore === undefined) return [];
    const predicates = new relationalStore.RdbPredicates('knowledge_tag');
    if (subject !== undefined) {
      predicates.equalTo('subject', subject);
    }
    if (grade !== undefined) {
      predicates.equalTo('grade', grade);
    }
    const resultSet = await this.rdbStore.query(predicates);
    const list: KnowledgeTag[] = [];
    while (resultSet.goToNextRow()) {
      const tag = new KnowledgeTag();
      tag.id = rs_col(resultSet, 'id');
      tag.subject = rs_col(resultSet, 'subject') as Subject;
      tag.grade = rs_col(resultSet, 'grade') as Grade;
      tag.textbookVersion = rs_col(resultSet, 'textbookVersion') as TextbookVersion;
      tag.name = rs_col(resultSet, 'name');
      tag.parentTagId = rs_col(resultSet, 'parentTagId');
      list.push(tag);
    }
    resultSet.close();
    return list;
  }

  async queryKnowledgeProfiles(studentId: string): Promise<KnowledgeProfile[]> {
    if (this.rdbStore === undefined) return [];
    const predicates = new relationalStore.RdbPredicates('knowledge_profile');
    predicates.equalTo('studentId', studentId);
    const resultSet = await this.rdbStore.query(predicates);
    const list: KnowledgeProfile[] = [];
    while (resultSet.goToNextRow()) {
      const p = new KnowledgeProfile();
      p.id = rs_col(resultSet, 'id');
      p.studentId = rs_col(resultSet, 'studentId');
      p.knowledgeTagId = rs_col(resultSet, 'knowledgeTagId');
      p.totalMistakes = rs_col_long(resultSet, 'totalMistakes');
      p.masteredCount = rs_col_long(resultSet, 'masteredCount');
      p.currentMasteryScore = rs_col_double(resultSet, 'currentMasteryScore');
      p.trend = rs_col(resultSet, 'trend') as Trend;
      p.updatedAt = rs_col_long(resultSet, 'updatedAt');
      list.push(p);
    }
    resultSet.close();
    return list;
  }

  async upsertKnowledgeProfile(profile: KnowledgeProfile): Promise<void> {
    if (this.rdbStore === undefined) return;
    const predicates = new relationalStore.RdbPredicates('knowledge_profile');
    predicates.equalTo('id', profile.id);
    const value: Record<string, relationalStore.ValueType> = {
      'id': profile.id, 'studentId': profile.studentId,
      'knowledgeTagId': profile.knowledgeTagId,
      'totalMistakes': profile.totalMistakes,
      'masteredCount': profile.masteredCount,
      'currentMasteryScore': profile.currentMasteryScore,
      'trend': profile.trend, 'updatedAt': profile.updatedAt
    };
    const updated: number = await this.rdbStore.update(value, predicates);
    if (updated === 0) {
      await this.rdbStore.insert('knowledge_profile', value);
    }
  }

  async queryKnowledgeTagsByIds(ids: string[]): Promise<KnowledgeTag[]> {
    if (this.rdbStore === undefined || ids.length === 0) return [];
    const predicates = new relationalStore.RdbPredicates('knowledge_tag');
    predicates.in('id', ids);
    const resultSet = await this.rdbStore.query(predicates);
    const list: KnowledgeTag[] = [];
    while (resultSet.goToNextRow()) {
      const tag = new KnowledgeTag();
      tag.id = rs_col(resultSet, 'id');
      tag.subject = rs_col(resultSet, 'subject') as Subject;
      tag.grade = rs_col(resultSet, 'grade') as Grade;
      tag.textbookVersion = rs_col(resultSet, 'textbookVersion') as TextbookVersion;
      tag.name = rs_col(resultSet, 'name');
      tag.parentTagId = rs_col(resultSet, 'parentTagId');
      list.push(tag);
    }
    resultSet.close();
    return list;
  }

  async insertStudent(s: Student): Promise<void> {
    if (this.rdbStore === undefined) return;
    const value: Record<string, relationalStore.ValueType> = {
      'id': s.id, 'parentId': s.parentId, 'nickname': s.nickname,
      'grade': s.grade, 'textbookVersion': s.textbookVersion,
      'region': s.region, 'school': s.school,
      'communityBrowseEnabled': s.communityBrowseEnabled ? 1 : 0,
      'communityShareEnabled': s.communityShareEnabled ? 1 : 0,
      'createdAt': s.createdAt
    };
    await this.rdbStore.insert('student', value);
  }

  async queryStudent(id: string): Promise<Student | undefined> {
    if (this.rdbStore === undefined) return undefined;
    const predicates = new relationalStore.RdbPredicates('student');
    predicates.equalTo('id', id);
    const resultSet = await this.rdbStore.query(predicates);
    if (resultSet.goToFirstRow()) {
      const s = new Student();
      s.id = rs_col(resultSet, 'id');
      s.parentId = rs_col(resultSet, 'parentId');
      s.nickname = rs_col(resultSet, 'nickname');
      s.grade = rs_col(resultSet, 'grade') as Grade;
      s.textbookVersion = rs_col(resultSet, 'textbookVersion') as TextbookVersion;
      s.region = rs_col(resultSet, 'region');
      s.school = rs_col(resultSet, 'school');
      s.communityBrowseEnabled = rs_col_long(resultSet, 'communityBrowseEnabled') === 1;
      s.communityShareEnabled = rs_col_long(resultSet, 'communityShareEnabled') === 1;
      s.createdAt = rs_col_long(resultSet, 'createdAt');
      resultSet.close();
      return s;
    }
    resultSet.close();
    return undefined;
  }

  async updateStudent(s: Student): Promise<void> {
    if (this.rdbStore === undefined) return;
    const value: Record<string, relationalStore.ValueType> = {
      'nickname': s.nickname, 'grade': s.grade,
      'textbookVersion': s.textbookVersion,
      'region': s.region, 'school': s.school,
      'communityBrowseEnabled': s.communityBrowseEnabled ? 1 : 0,
      'communityShareEnabled': s.communityShareEnabled ? 1 : 0
    };
    const predicates = new relationalStore.RdbPredicates('student');
    predicates.equalTo('id', s.id);
    await this.rdbStore.update(value, predicates);
  }

  async insertPointsLog(log: PointsLog): Promise<void> {
    if (this.rdbStore === undefined) return;
    const value: Record<string, relationalStore.ValueType> = {
      'id': log.id, 'studentId': log.studentId,
      'actionType': log.actionType, 'points': log.points,
      'createdAt': log.createdAt
    };
    await this.rdbStore.insert('points_log', value);
  }

  async queryPointsSummary(studentId: string): Promise<PointsSummary> {
    if (this.rdbStore === undefined) {
      const s = new PointsSummary();
      return s;
    }
    const predicates = new relationalStore.RdbPredicates('points_log');
    predicates.equalTo('studentId', studentId);
    const resultSet = await this.rdbStore.query(predicates);
    let total = 0;
    let todayTotal = 0;
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayMs = todayStart.getTime();
    while (resultSet.goToNextRow()) {
      const pts = rs_col_long(resultSet, 'points');
      const createdAt = rs_col_long(resultSet, 'createdAt');
      total += pts;
      if (createdAt >= todayMs) {
        todayTotal += pts;
      }
    }
    resultSet.close();
    const summary = new PointsSummary();
    summary.totalPoints = total;
    summary.todayPoints = todayTotal;
    summary.streakDays = 0;
    return summary;
  }

  async queryPointsLogs(studentId: string): Promise<PointsLog[]> {
    if (this.rdbStore === undefined) return [];
    const predicates = new relationalStore.RdbPredicates('points_log');
    predicates.equalTo('studentId', studentId);
    predicates.orderByDesc('createdAt');
    const resultSet = await this.rdbStore.query(predicates);
    const list: PointsLog[] = [];
    while (resultSet.goToNextRow()) {
      const log = new PointsLog();
      log.id = rs_col(resultSet, 'id');
      log.studentId = rs_col(resultSet, 'studentId');
      log.actionType = rs_col(resultSet, 'actionType') as PointsActionType;
      log.points = rs_col_long(resultSet, 'points');
      log.createdAt = rs_col_long(resultSet, 'createdAt');
      list.push(log);
    }
    resultSet.close();
    return list;
  }

  async queryReminderSettings(studentId: string): Promise<ReminderSettings> {
    const fallback: ReminderSettings = ReminderSettings.create(studentId);
    if (this.rdbStore === undefined) return fallback;
    const predicates = new relationalStore.RdbPredicates('reminder_settings');
    predicates.equalTo('studentId', studentId);
    const resultSet = await this.rdbStore.query(predicates);
    if (resultSet.goToFirstRow()) {
      const r = new ReminderSettings();
      r.id = rs_col(resultSet, 'id');
      r.studentId = rs_col(resultSet, 'studentId');
      r.reviewTimeStart = rs_col(resultSet, 'reviewTimeStart');
      r.reviewTimeEnd = rs_col(resultSet, 'reviewTimeEnd');
      r.dailyLimit = rs_col_long(resultSet, 'dailyLimit');
      r.mathEnabled = rs_col_long(resultSet, 'mathEnabled') === 1;
      r.chineseEnabled = rs_col_long(resultSet, 'chineseEnabled') === 1;
      r.englishEnabled = rs_col_long(resultSet, 'englishEnabled') === 1;
      r.scienceEnabled = rs_col_long(resultSet, 'scienceEnabled') === 1;
      r.doNotDisturb = rs_col_long(resultSet, 'doNotDisturb') === 1;
      r.notificationEnabled = rs_col_long(resultSet, 'notificationEnabled') === 1;
      r.updatedAt = rs_col_long(resultSet, 'updatedAt');
      resultSet.close();
      return r;
    }
    resultSet.close();
    return fallback;
  }

  async saveReminderSettings(r: ReminderSettings): Promise<void> {
    if (this.rdbStore === undefined) return;
    r.updatedAt = Date.now();
    const predicates = new relationalStore.RdbPredicates('reminder_settings');
    predicates.equalTo('studentId', r.studentId);
    const value: Record<string, relationalStore.ValueType> = {
      'id': r.id + '_' + r.studentId, 'studentId': r.studentId,
      'reviewTimeStart': r.reviewTimeStart, 'reviewTimeEnd': r.reviewTimeEnd,
      'dailyLimit': r.dailyLimit, 'mathEnabled': r.mathEnabled ? 1 : 0,
      'chineseEnabled': r.chineseEnabled ? 1 : 0,
      'englishEnabled': r.englishEnabled ? 1 : 0,
      'scienceEnabled': r.scienceEnabled ? 1 : 0,
      'doNotDisturb': r.doNotDisturb ? 1 : 0,
      'notificationEnabled': r.notificationEnabled ? 1 : 0,
      'updatedAt': r.updatedAt
    };
    const updated: number = await this.rdbStore.update(value, predicates);
    if (updated === 0) {
      await this.rdbStore.insert('reminder_settings', value);
    }
  }

  async insertAnalyticsEvent(e: AnalyticsEvent): Promise<void> {
    if (this.rdbStore === undefined) return;
    const value: Record<string, relationalStore.ValueType> = {
      'id': e.id, 'eventType': e.eventType, 'studentIdHash': e.studentIdHash,
      'platform': e.platform, 'properties': e.properties, 'occurredAt': e.occurredAt
    };
    await this.rdbStore.insert('analytics_event', value);
  }

  async queryMetricSummary(): Promise<MetricSummary> {
    const summary = new MetricSummary();
    if (this.rdbStore === undefined) return summary;
    const predicates = new relationalStore.RdbPredicates('analytics_event');
    const resultSet = await this.rdbStore.query(predicates);
    let confSum: number = 0;
    let confCount: number = 0;
    let reviewCorrect: number = 0;
    while (resultSet.goToNextRow()) {
      const type: string = rs_col(resultSet, 'eventType');
      if (type === 'capture') {
        summary.captureCount++;
      } else if (type === 'review_submit') {
        summary.reviewSubmitCount++;
        const props: string = rs_col(resultSet, 'properties');
        if (props.indexOf('correct') >= 0 && props.indexOf('"correct":true') >= 0) {
          reviewCorrect++;
        }
      } else if (type === 'mastery_achieved') {
        summary.masteryAchievedCount++;
      } else if (type === 'ocr_confirm') {
        summary.ocrConfirmCount++;
        const props: string = rs_col(resultSet, 'properties');
        const parsed = parseConfidence(props);
        if (parsed >= 0) {
          confSum += parsed;
          confCount++;
        }
      }
    }
    resultSet.close();
    summary.avgOcrConfidence = confCount > 0 ? confSum / confCount : 0;
    summary.reviewAccuracy = summary.reviewSubmitCount > 0 ? reviewCorrect / summary.reviewSubmitCount : 0;
    return summary;
  }

  async insertRedemption(studentId: string, itemId: string, cost: number): Promise<void> {
    if (this.rdbStore === undefined) return;
    const value: Record<string, relationalStore.ValueType> = {
      'id': Date.now().toString(36) + Math.random().toString(36).substring(2, 6),
      'studentId': studentId, 'itemId': itemId, 'cost': cost,
      'redeemedAt': Date.now()
    };
    await this.rdbStore.insert('redemption', value);
  }

  async queryRedeemedItemIds(studentId: string): Promise<string[]> {
    if (this.rdbStore === undefined) return [];
    const predicates = new relationalStore.RdbPredicates('redemption');
    predicates.equalTo('studentId', studentId);
    const resultSet = await this.rdbStore.query(predicates);
    const ids: string[] = [];
    while (resultSet.goToNextRow()) {
      ids.push(rs_col(resultSet, 'itemId'));
    }
    resultSet.close();
    return ids;
  }

  async queryTotalSpent(studentId: string): Promise<number> {
    if (this.rdbStore === undefined) return 0;
    const predicates = new relationalStore.RdbPredicates('redemption');
    predicates.equalTo('studentId', studentId);
    const resultSet = await this.rdbStore.query(predicates);
    let total: number = 0;
    while (resultSet.goToNextRow()) {
      total += rs_col_long(resultSet, 'cost');
    }
    resultSet.close();
    return total;
  }
}

function parseConfidence(props: string): number {
  const marker: string = '"confidence":';
  const idx: number = props.indexOf(marker);
  if (idx < 0) {
    return -1;
  }
  const rest: string = props.substring(idx + marker.length);
  let end: number = 0;
  while (end < rest.length && rest.charAt(end) !== ',' && rest.charAt(end) !== '}') {
    end++;
  }
  const numStr: string = rest.substring(0, end);
  const val: number = parseFloat(numStr);
  return isNaN(val) ? -1 : val;
}

function rs_col(rs: relationalStore.ResultSet, col: string): string {
  const idx = rs.getColumnIndex(col);
  return rs.getString(idx);
}

function rs_col_long(rs: relationalStore.ResultSet, col: string): number {
  const idx = rs.getColumnIndex(col);
  return rs.getLong(idx);
}

function rs_col_double(rs: relationalStore.ResultSet, col: string): number {
  const idx = rs.getColumnIndex(col);
  return rs.getDouble(idx);
}

export const dbHelper = new DatabaseHelper();
