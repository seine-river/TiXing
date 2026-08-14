import { relationalStore } from '@kit.ArkData';
import { Mistake } from '../models/Mistake';
import { ReviewLog } from '../models/ReviewLog';
import { KnowledgeTag, KnowledgeProfile } from '../models/KnowledgeTag';
import { Student, ParentAccount } from '../models/Student';
import { PointsLog, PointsSummary } from '../models/PointsLog';
import { CommunityPost } from '../models/CommunityPost';
import { ReminderSettings } from '../models/ReminderSettings';
import { AnalyticsEvent, MetricSummary, ReviewStats } from '../models/AnalyticsEvent';
import {
  Subject, Grade, ErrorType, MistakeStatus, AnswerType, GradingMethod,
  InputMethod, SyncStatus, PointsActionType, CommunityPostStatus,
  TextbookVersion, Trend, SubscriptionStatus
} from '../models/Enums';

const DB_NAME: string = 'tixing.db';

const CREATE_MISTAKE_TABLE: string =
  `CREATE TABLE IF NOT EXISTS mistake (
    id TEXT PRIMARY KEY, studentId TEXT, imageUrl TEXT, ocrText TEXT,
    ocrConfidence REAL, isConfirmed INTEGER, subject TEXT, knowledgeTagIds TEXT,
    errorType TEXT, status TEXT, intervalIndex INTEGER, nextReviewDate INTEGER,
    firstReviewDuration INTEGER, standardAnswer TEXT, studentAnswer TEXT,
    knowledgeSummary TEXT, answerType TEXT,
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
    try {
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
      await this.migrateAllTables();
      await this.seedKnowledgeTags();
    } catch (e) {
    }
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
      this.makeTag('kt_g4_chinese_02', Subject.CHINESE, Grade.G4, TextbookVersion.PEP, '作文基础', '')
    ];
    for (const tag of seeds) {
      await this.insertKnowledgeTag(tag);
    }
  }

  private async migrateAllTables(): Promise<void> {
    if (this.rdbStore === undefined) {
      return;
    }
    const migrations: string[] = [
      'ALTER TABLE mistake ADD COLUMN imageUrl TEXT',
      'ALTER TABLE mistake ADD COLUMN ocrText TEXT',
      'ALTER TABLE mistake ADD COLUMN ocrConfidence REAL',
      'ALTER TABLE mistake ADD COLUMN isConfirmed INTEGER',
      'ALTER TABLE mistake ADD COLUMN subject TEXT',
      'ALTER TABLE mistake ADD COLUMN knowledgeTagIds TEXT',
      'ALTER TABLE mistake ADD COLUMN errorType TEXT',
      'ALTER TABLE mistake ADD COLUMN status TEXT',
      'ALTER TABLE mistake ADD COLUMN intervalIndex INTEGER',
      'ALTER TABLE mistake ADD COLUMN nextReviewDate INTEGER',
      'ALTER TABLE mistake ADD COLUMN firstReviewDuration INTEGER',
      'ALTER TABLE mistake ADD COLUMN standardAnswer TEXT',
      'ALTER TABLE mistake ADD COLUMN studentAnswer TEXT',
      'ALTER TABLE mistake ADD COLUMN knowledgeSummary TEXT',
      'ALTER TABLE mistake ADD COLUMN answerType TEXT',
      'ALTER TABLE mistake ADD COLUMN notes TEXT',
      'ALTER TABLE mistake ADD COLUMN notesAttachmentUrl TEXT',
      'ALTER TABLE mistake ADD COLUMN sharedToCommunity INTEGER',
      'ALTER TABLE mistake ADD COLUMN communityPostId TEXT',
      'ALTER TABLE mistake ADD COLUMN createdAt INTEGER',
      'ALTER TABLE mistake ADD COLUMN syncStatus TEXT',
      'ALTER TABLE review_log ADD COLUMN mistakeId TEXT',
      'ALTER TABLE review_log ADD COLUMN reviewTime INTEGER',
      'ALTER TABLE review_log ADD COLUMN gradingMethod TEXT',
      'ALTER TABLE review_log ADD COLUMN inputMethod TEXT',
      'ALTER TABLE review_log ADD COLUMN correct INTEGER',
      'ALTER TABLE review_log ADD COLUMN durationSeconds INTEGER',
      'ALTER TABLE review_log ADD COLUMN pointsAwarded INTEGER',
      'ALTER TABLE review_log ADD COLUMN clientOperationId TEXT',
      'ALTER TABLE reminder_settings ADD COLUMN reviewTimeStart TEXT',
      'ALTER TABLE reminder_settings ADD COLUMN reviewTimeEnd TEXT',
      'ALTER TABLE reminder_settings ADD COLUMN dailyLimit INTEGER',
      'ALTER TABLE reminder_settings ADD COLUMN mathEnabled INTEGER',
      'ALTER TABLE reminder_settings ADD COLUMN chineseEnabled INTEGER',
      'ALTER TABLE reminder_settings ADD COLUMN englishEnabled INTEGER',
      'ALTER TABLE reminder_settings ADD COLUMN scienceEnabled INTEGER',
      'ALTER TABLE reminder_settings ADD COLUMN doNotDisturb INTEGER',
      'ALTER TABLE reminder_settings ADD COLUMN notificationEnabled INTEGER',
      'ALTER TABLE reminder_settings ADD COLUMN updatedAt INTEGER',
      'ALTER TABLE analytics_event ADD COLUMN eventType TEXT',
      'ALTER TABLE analytics_event ADD COLUMN studentIdHash TEXT',
      'ALTER TABLE analytics_event ADD COLUMN platform TEXT',
      'ALTER TABLE analytics_event ADD COLUMN properties TEXT',
      'ALTER TABLE analytics_event ADD COLUMN occurredAt INTEGER'
    ];
    for (const sql of migrations) {
      try {
        await this.rdbStore.executeSql(sql);
      } catch (e) {
      }
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
      'standardAnswer': m.standardAnswer, 'studentAnswer': m.studentAnswer,
      'knowledgeSummary': m.knowledgeSummary, 'answerType': m.answerType,
      'notes': m.notes, 'notesAttachmentUrl': m.notesAttachmentUrl,
      'sharedToCommunity': m.sharedToCommunity ? 1 : 0,
      'communityPostId': m.communityPostId, 'createdAt': m.createdAt,
      'syncStatus': m.syncStatus
    };
    try {
      await this.rdbStore.insert('mistake', value);
    } catch (e) {
    }
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
      'standardAnswer': m.standardAnswer, 'studentAnswer': m.studentAnswer,
      'knowledgeSummary': m.knowledgeSummary, 'answerType': m.answerType,
      'notes': m.notes, 'notesAttachmentUrl': m.notesAttachmentUrl,
      'syncStatus': m.syncStatus
    };
    const predicates = new relationalStore.RdbPredicates('mistake');
    predicates.equalTo('id', m.id);
    try {
      await this.rdbStore.update(value, predicates);
    } catch (e) {
    }
  }

  async queryMistakes(subject?: Subject, status?: MistakeStatus, keyword?: string, errorType?: ErrorType): Promise<Mistake[]> {
    if (this.rdbStore === undefined) return [];
    const list: Mistake[] = [];
    try {
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
      while (resultSet.goToNextRow()) {
        list.push(this.rowToMistake(resultSet));
      }
      resultSet.close();
    } catch (e) {
    }
    return list;
  }

  async queryMistakeById(id: string): Promise<Mistake | undefined> {
    if (this.rdbStore === undefined) return undefined;
    try {
      const predicates = new relationalStore.RdbPredicates('mistake');
      predicates.equalTo('id', id);
      const resultSet = await this.rdbStore.query(predicates);
      if (resultSet.goToFirstRow()) {
        const m = this.rowToMistake(resultSet);
        resultSet.close();
        return m;
      }
      resultSet.close();
    } catch (e) {
    }
    return undefined;
  }

  async queryTodayReviewMistakes(): Promise<Mistake[]> {
    if (this.rdbStore === undefined) return [];
    const list: Mistake[] = [];
    try {
      const now = Date.now();
      const predicates = new relationalStore.RdbPredicates('mistake');
      predicates.lessThanOrEqualTo('nextReviewDate', now);
      predicates.notEqualTo('status', MistakeStatus.MASTERED);
      predicates.orderByAsc('nextReviewDate');
      const resultSet = await this.rdbStore.query(predicates);
      while (resultSet.goToNextRow()) {
        list.push(this.rowToMistake(resultSet));
      }
      resultSet.close();
    } catch (e) {
    }
    return list;
  }

  async deleteMistake(id: string): Promise<void> {
    if (this.rdbStore === undefined) return;
    try {
      const p1 = new relationalStore.RdbPredicates('mistake');
      p1.equalTo('id', id);
      await this.rdbStore.delete(p1);
      const p2 = new relationalStore.RdbPredicates('review_log');
      p2.equalTo('mistakeId', id);
      await this.rdbStore.delete(p2);
    } catch (e) {
    }
  }

  async queryReviewStats(): Promise<ReviewStats> {
    const stats = new ReviewStats();
    if (this.rdbStore === undefined) return stats;
    try {
      const resultSet = await this.rdbStore.query(new relationalStore.RdbPredicates('review_log'));
      while (resultSet.goToNextRow()) {
        stats.total++;
        if (rs_col_long(resultSet, 'correct') === 1) {
          stats.correct++;
        }
      }
      resultSet.close();
    } catch (e) {
    }
    return stats;
  }

  private rowToMistake(rs: relationalStore.ResultSet): Mistake {
    const m = new Mistake();
    try {
      m.id = rs_col(rs, 'id');
      m.studentId = rs_col(rs, 'studentId');
      m.imageUrl = rs_col(rs, 'imageUrl');
      m.ocrText = rs_col(rs, 'ocrText');
      m.ocrConfidence = rs_col_double(rs, 'ocrConfidence');
      m.isConfirmed = rs_col_long(rs, 'isConfirmed') === 1;
      m.subject = rs_col(rs, 'subject') as Subject;
      const tagStr = rs_col(rs, 'knowledgeTagIds');
      m.knowledgeTagIds = tagStr.length > 0 ? tagStr.split(',') : [];
      m.errorType = rs_col(rs, 'errorType') as ErrorType;
      m.status = rs_col(rs, 'status') as MistakeStatus;
      m.intervalIndex = rs_col_long(rs, 'intervalIndex');
      m.nextReviewDate = rs_col_long(rs, 'nextReviewDate');
      m.firstReviewDuration = rs_col_long(rs, 'firstReviewDuration');
      m.standardAnswer = rs_col(rs, 'standardAnswer');
      m.studentAnswer = rs_col(rs, 'studentAnswer');
      m.knowledgeSummary = rs_col(rs, 'knowledgeSummary');
      m.answerType = rs_col(rs, 'answerType') as AnswerType;
      m.notes = rs_col(rs, 'notes');
      m.notesAttachmentUrl = rs_col(rs, 'notesAttachmentUrl');
      m.sharedToCommunity = rs_col_long(rs, 'sharedToCommunity') === 1;
      m.communityPostId = rs_col(rs, 'communityPostId');
      m.createdAt = rs_col_long(rs, 'createdAt');
      m.syncStatus = rs_col(rs, 'syncStatus') as SyncStatus;
    } catch (e) {
    }
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
    try {
      await this.rdbStore.insert('review_log', value);
    } catch (e) {
    }
  }

  async queryReviewLogs(mistakeId: string): Promise<ReviewLog[]> {
    if (this.rdbStore === undefined) return [];
    const list: ReviewLog[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('review_log');
      predicates.equalTo('mistakeId', mistakeId);
      predicates.orderByDesc('reviewTime');
      const resultSet = await this.rdbStore.query(predicates);
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
    } catch (e) {
    }
    return list;
  }

  async insertKnowledgeTag(tag: KnowledgeTag): Promise<void> {
    if (this.rdbStore === undefined) return;
    const value: Record<string, relationalStore.ValueType> = {
      'id': tag.id, 'subject': tag.subject, 'grade': tag.grade,
      'textbookVersion': tag.textbookVersion, 'name': tag.name,
      'parentTagId': tag.parentTagId
    };
    try {
      await this.rdbStore.insert('knowledge_tag', value);
    } catch (e) {
    }
  }

  async queryKnowledgeTags(subject?: Subject, grade?: Grade): Promise<KnowledgeTag[]> {
    if (this.rdbStore === undefined) return [];
    const list: KnowledgeTag[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('knowledge_tag');
      if (subject !== undefined) {
        predicates.equalTo('subject', subject);
      }
      if (grade !== undefined) {
        predicates.equalTo('grade', grade);
      }
      const resultSet = await this.rdbStore.query(predicates);
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
    } catch (e) {
    }
    return list;
  }

  async queryKnowledgeProfiles(studentId: string): Promise<KnowledgeProfile[]> {
    if (this.rdbStore === undefined) return [];
    const list: KnowledgeProfile[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('knowledge_profile');
      predicates.equalTo('studentId', studentId);
      const resultSet = await this.rdbStore.query(predicates);
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
    } catch (e) {
    }
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
    try {
      const updated: number = await this.rdbStore.update(value, predicates);
      if (updated === 0) {
        await this.rdbStore.insert('knowledge_profile', value);
      }
    } catch (e) {
    }
  }

  async queryKnowledgeTagsByIds(ids: string[]): Promise<KnowledgeTag[]> {
    if (this.rdbStore === undefined || ids.length === 0) return [];
    const list: KnowledgeTag[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('knowledge_tag');
      predicates.in('id', ids);
      const resultSet = await this.rdbStore.query(predicates);
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
    } catch (e) {
    }
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
    try {
      await this.rdbStore.insert('student', value);
    } catch (e) {
    }
  }

  async queryStudent(id: string): Promise<Student | undefined> {
    if (this.rdbStore === undefined) return undefined;
    try {
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
    } catch (e) {
    }
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
    try {
      await this.rdbStore.update(value, predicates);
    } catch (e) {
    }
  }

  async insertPointsLog(log: PointsLog): Promise<void> {
    if (this.rdbStore === undefined) return;
    const value: Record<string, relationalStore.ValueType> = {
      'id': log.id, 'studentId': log.studentId,
      'actionType': log.actionType, 'points': log.points,
      'createdAt': log.createdAt
    };
    try {
      await this.rdbStore.insert('points_log', value);
    } catch (e) {
    }
  }

  async queryPointsSummary(studentId: string): Promise<PointsSummary> {
    const summary = new PointsSummary();
    if (this.rdbStore === undefined) return summary;
    try {
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
      summary.totalPoints = total;
      summary.todayPoints = todayTotal;
      summary.streakDays = 0;
    } catch (e) {
    }
    return summary;
  }

  async queryPointsLogs(studentId: string): Promise<PointsLog[]> {
    if (this.rdbStore === undefined) return [];
    const list: PointsLog[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('points_log');
      predicates.equalTo('studentId', studentId);
      predicates.orderByDesc('createdAt');
      const resultSet = await this.rdbStore.query(predicates);
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
    } catch (e) {
    }
    return list;
  }

  async queryReminderSettings(studentId: string): Promise<ReminderSettings> {
    const fallback: ReminderSettings = ReminderSettings.create(studentId);
    if (this.rdbStore === undefined) return fallback;
    try {
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
    } catch (e) {
    }
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
    try {
      const updated: number = await this.rdbStore.update(value, predicates);
      if (updated === 0) {
        await this.rdbStore.insert('reminder_settings', value);
      }
    } catch (e) {
    }
  }

  async insertAnalyticsEvent(e: AnalyticsEvent): Promise<void> {
    if (this.rdbStore === undefined) return;
    const value: Record<string, relationalStore.ValueType> = {
      'id': e.id, 'eventType': e.eventType, 'studentIdHash': e.studentIdHash,
      'platform': e.platform, 'properties': e.properties, 'occurredAt': e.occurredAt
    };
    try {
      await this.rdbStore.insert('analytics_event', value);
    } catch (e) {
    }
  }

  async queryMetricSummary(): Promise<MetricSummary> {
    const summary = new MetricSummary();
    if (this.rdbStore === undefined) return summary;
    try {
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
    } catch (e) {
    }
    return summary;
  }

  async insertRedemption(studentId: string, itemId: string, cost: number): Promise<void> {
    if (this.rdbStore === undefined) return;
    const value: Record<string, relationalStore.ValueType> = {
      'id': Date.now().toString(36) + Math.random().toString(36).substring(2, 6),
      'studentId': studentId, 'itemId': itemId, 'cost': cost,
      'redeemedAt': Date.now()
    };
    try {
      await this.rdbStore.insert('redemption', value);
    } catch (e) {
    }
  }

  async queryRedeemedItemIds(studentId: string): Promise<string[]> {
    if (this.rdbStore === undefined) return [];
    const ids: string[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('redemption');
      predicates.equalTo('studentId', studentId);
      const resultSet = await this.rdbStore.query(predicates);
      while (resultSet.goToNextRow()) {
        ids.push(rs_col(resultSet, 'itemId'));
      }
      resultSet.close();
    } catch (e) {
    }
    return ids;
  }

  async queryTotalSpent(studentId: string): Promise<number> {
    if (this.rdbStore === undefined) return 0;
    let total: number = 0;
    try {
      const predicates = new relationalStore.RdbPredicates('redemption');
      predicates.equalTo('studentId', studentId);
      const resultSet = await this.rdbStore.query(predicates);
      while (resultSet.goToNextRow()) {
        total += rs_col_long(resultSet, 'cost');
      }
      resultSet.close();
    } catch (e) {
    }
    return total;
  }
}

function parseConfidence(props: string): number {
  try {
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
  } catch (e) {
    return -1;
  }
}

function rs_col(rs: relationalStore.ResultSet, col: string): string {
  try {
    const idx = rs.getColumnIndex(col);
    return rs.getString(idx);
  } catch (e) {
    return '';
  }
}

function rs_col_long(rs: relationalStore.ResultSet, col: string): number {
  try {
    const idx = rs.getColumnIndex(col);
    return rs.getLong(idx);
  } catch (e) {
    return 0;
  }
}

function rs_col_double(rs: relationalStore.ResultSet, col: string): number {
  try {
    const idx = rs.getColumnIndex(col);
    return rs.getDouble(idx);
  } catch (e) {
    return 0;
  }
}

export const dbHelper = new DatabaseHelper();
