import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Mistake } from '../models/Mistake';
import { ReviewLog } from '../models/ReviewLog';
import { KnowledgeTag, KnowledgeProfile } from '../models/KnowledgeTag';
import { Student } from '../models/Student';
import { PointsLog, PointsSummary } from '../models/PointsLog';
import { ReminderSettings } from '../models/ReminderSettings';
import { AnalyticsEvent, MetricSummary, ReviewStats, MistakeStats, SubjectCount } from '../models/AnalyticsEvent';
import { DbResult } from '../common/DbResult';
import {
  Subject, Grade, ErrorType, MistakeStatus, AnswerType, GradingMethod,
  InputMethod, SyncStatus, PointsActionType, TextbookVersion, Trend
} from '../models/Enums';

const DB_NAME: string = 'tixing.db';
const DB_VERSION: number = 2;

const DB_LOG_DOMAIN: number = 0xA002;
const DB_LOG_TAG: string = 'TiXingDb';

/**
 * 统一日志封装（D2）：所有数据库错误经此处记录 tag+操作+原因，不再空 catch。
 */
class DbLog {
  static error(op: string, reason: string): void {
    try {
      hilog.error(DB_LOG_DOMAIN, DB_LOG_TAG, '[db] %{public}s failed: %{public}s', op, reason);
    } catch (e) {
    }
  }

  static info(op: string, msg: string): void {
    try {
      hilog.info(DB_LOG_DOMAIN, DB_LOG_TAG, '[db] %{public}s: %{public}s', op, msg);
    } catch (e) {
    }
  }

  static warn(op: string, msg: string): void {
    try {
      hilog.warn(DB_LOG_DOMAIN, DB_LOG_TAG, '[db] %{public}s: %{public}s', op, msg);
    } catch (e) {
    }
  }
}

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

const CREATE_INDEXES: string[] = [
  'CREATE INDEX IF NOT EXISTS idx_mistake_next_review ON mistake(nextReviewDate)',
  'CREATE INDEX IF NOT EXISTS idx_mistake_student ON mistake(studentId)',
  'CREATE INDEX IF NOT EXISTS idx_review_log_mistake ON review_log(mistakeId)',
  'CREATE INDEX IF NOT EXISTS idx_review_log_time ON review_log(reviewTime)',
  'CREATE INDEX IF NOT EXISTS idx_points_log_student ON points_log(studentId)',
  'CREATE INDEX IF NOT EXISTS idx_analytics_event_type ON analytics_event(eventType)',
  'CREATE INDEX IF NOT EXISTS idx_knowledge_profile_student ON knowledge_profile(studentId)',
  'CREATE INDEX IF NOT EXISTS idx_redemption_student ON redemption(studentId)'
];

/**
 * 版本化迁移（D9）：v0 = 存量无版本库或全新库，执行幂等 ALTER 合集 + 建表 + 索引后置 v2。
 */
const LEGACY_MIGRATIONS: string[] = [
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

export class DatabaseHelper {
  private static instance: DatabaseHelper | undefined = undefined;

  private rdbStore: relationalStore.RdbStore | undefined = undefined;
  private readyPromise: Promise<DbResult> | undefined = undefined;

  private constructor() {
  }

  /** 单例收敛（T004）：constructor 私有化，全局经 getInstance / dbHelper 访问。 */
  static getInstance(): DatabaseHelper {
    if (DatabaseHelper.instance === undefined) {
      DatabaseHelper.instance = new DatabaseHelper();
    }
    return DatabaseHelper.instance;
  }

  /**
   * init 幂等（T005）：缓存就绪 Promise；失败返回 DbResult 并记致命日志。
   */
  async init(context: common.Context): Promise<DbResult> {
    if (this.readyPromise !== undefined) {
      return this.readyPromise;
    }
    this.readyPromise = this.doInit(context);
    return this.readyPromise;
  }

  /** 就绪机制（T005/D3）：页面在查询前等待数据库就绪。 */
  whenReady(): Promise<void> {
    if (this.readyPromise === undefined) {
      return Promise.resolve();
    }
    return this.readyPromise.then((_r: DbResult): void => {
    });
  }

  /** 数据库是否已就绪（供页面区分失败态与空数据）。 */
  isReady(): boolean {
    return this.rdbStore !== undefined;
  }

  private async doInit(context: common.Context): Promise<DbResult> {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    let store: relationalStore.RdbStore;
    try {
      store = await relationalStore.getRdbStore(context, config);
    } catch (e) {
      const reason: string = errText(e);
      DbLog.error('init/getRdbStore', reason);
      return DbResult.fail('init', '数据库打开失败: ' + reason);
    }

    try {
      const version: number = await this.readUserVersion(store);
      if (version < DB_VERSION) {
        if (version === 0) {
          // v0：存量库（幂等 ALTER 合集）或全新库（建表即最新结构）
          await this.executeAll(store, this.tableDdlList(), 'createTables');
          await this.runLegacyMigrations(store);
        }
        await this.executeAll(store, CREATE_INDEXES, 'createIndexes');
        await store.executeSql(`PRAGMA user_version = ${DB_VERSION}`);
        DbLog.info('init', `migrated db schema to v${DB_VERSION} from v${version}`);
      }
      this.rdbStore = store;
      return await this.seedKnowledgeTags(store);
    } catch (e) {
      const reason: string = errText(e);
      DbLog.error('init/migrate', reason);
      return DbResult.fail('init', '数据库迁移失败: ' + reason);
    }
  }

  private tableDdlList(): string[] {
    return [
      CREATE_MISTAKE_TABLE, CREATE_REVIEW_LOG_TABLE, CREATE_KNOWLEDGE_TAG_TABLE,
      CREATE_KNOWLEDGE_PROFILE_TABLE, CREATE_STUDENT_TABLE, CREATE_PARENT_TABLE,
      CREATE_POINTS_LOG_TABLE, CREATE_COMMUNITY_POST_TABLE, CREATE_REMINDER_SETTINGS_TABLE,
      CREATE_ANALYTICS_EVENT_TABLE, CREATE_REDEMPTION_TABLE
    ];
  }

  private async executeAll(store: relationalStore.RdbStore, sqlList: string[], op: string): Promise<void> {
    for (const sql of sqlList) {
      try {
        await store.executeSql(sql);
      } catch (e) {
        DbLog.error(op, sql.substring(0, 60) + ' :: ' + errText(e));
        throw new Error(`${op} 失败: ${errText(e)}`);
      }
    }
  }

  private async runLegacyMigrations(store: relationalStore.RdbStore): Promise<void> {
    for (const sql of LEGACY_MIGRATIONS) {
      try {
        await store.executeSql(sql);
      } catch (e) {
        const msg: string = errText(e);
        if (msg.indexOf('duplicate column') >= 0) {
          // 幂等预期：列已存在，跳过
          continue;
        }
        DbLog.warn('migrate', sql.substring(0, 60) + ' :: ' + msg);
      }
    }
  }

  private async readUserVersion(store: relationalStore.RdbStore): Promise<number> {
    const rs = await store.querySql('PRAGMA user_version');
    try {
      if (rs.goToFirstRow()) {
        return rs.getLong(rs.getColumnIndex('user_version'));
      }
      return 0;
    } finally {
      rs.close();
    }
  }

  /**
   * 就绪兜底（D3）：全部公开读写方法入口先等待就绪 Promise。
   */
  private async awaitStore(op: string): Promise<relationalStore.RdbStore | undefined> {
    if (this.readyPromise !== undefined) {
      const ready: DbResult = await this.readyPromise;
      if (!ready.success) {
        DbLog.warn(op, 'db init failed earlier: ' + ready.reason);
        return undefined;
      }
    }
    return this.rdbStore;
  }

  private notReady(op: string): DbResult {
    DbLog.error(op, 'db not ready');
    return DbResult.fail(op, '数据库未就绪');
  }

  /** 统一写操作封装（T006）：成功 ok / 失败 fail+日志。 */
  private async runWrite(op: string, action: () => Promise<void>): Promise<DbResult> {
    try {
      await action();
      return DbResult.ok();
    } catch (e) {
      const reason: string = errText(e);
      DbLog.error(op, reason);
      return DbResult.fail(op, reason);
    }
  }

  /** 通用事务（T008/T027）：action 内任一步失败整体回滚。 */
  async runInTransaction(op: string, action: () => Promise<DbResult>): Promise<DbResult> {
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return this.notReady(op);
    }
    store.beginTransaction();
    try {
      const result: DbResult = await action();
      if (!result.success) {
        store.rollBack();
        return result;
      }
      store.commit();
      return result;
    } catch (e) {
      try {
        store.rollBack();
      } catch (e2) {
        DbLog.warn(op, 'rollback failed: ' + errText(e2));
      }
      const reason: string = errText(e);
      DbLog.error(op, reason);
      return DbResult.fail(op, reason);
    }
  }

  private async seedKnowledgeTags(store: relationalStore.RdbStore): Promise<DbResult> {
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
    store.beginTransaction();
    try {
      for (const tag of seeds) {
        const value: Record<string, relationalStore.ValueType> = {
          'id': tag.id, 'subject': tag.subject, 'grade': tag.grade,
          'textbookVersion': tag.textbookVersion, 'name': tag.name,
          'parentTagId': tag.parentTagId
        };
        await store.insert('knowledge_tag', value, relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
      }
      store.commit();
      return DbResult.ok();
    } catch (e) {
      try {
        store.rollBack();
      } catch (e2) {
        DbLog.warn('seedKnowledgeTags', 'rollback failed: ' + errText(e2));
      }
      const reason: string = errText(e);
      DbLog.error('seedKnowledgeTags', reason);
      return DbResult.fail('seedKnowledgeTags', reason);
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

  // ---------------------- mistake ----------------------

  async insertMistake(m: Mistake): Promise<DbResult> {
    const op: string = 'insertMistake';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return this.notReady(op);
    }
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
    return this.runWrite(op, async (): Promise<void> => {
      await store.insert('mistake', value);
    });
  }

  async updateMistake(m: Mistake): Promise<DbResult> {
    const op: string = 'updateMistake';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return this.notReady(op);
    }
    const value: Record<string, relationalStore.ValueType> = {
      'imageUrl': m.imageUrl,
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
    return this.runWrite(op, async (): Promise<void> => {
      await store.update(value, predicates);
    });
  }

  async queryMistakes(subject?: Subject, status?: MistakeStatus, keyword?: string, errorType?: ErrorType,
    offset?: number, limit?: number): Promise<Mistake[]> {
    const op: string = 'queryMistakes';
    const list: Mistake[] = [];
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return list;
    }
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
      if (offset !== undefined && offset > 0) {
        predicates.offsetAs(offset);
      }
      if (limit !== undefined && limit > 0) {
        predicates.limitAs(limit);
      }
      const resultSet = await store.query(predicates);
      try {
        while (resultSet.goToNextRow()) {
          const m: Mistake | undefined = this.rowToMistake(resultSet);
          if (m !== undefined) {
            list.push(m);
          }
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return list;
  }

  async queryMistakesByStudent(studentId: string, offset?: number, limit?: number): Promise<Mistake[]> {
    const op: string = 'queryMistakesByStudent';
    const list: Mistake[] = [];
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return list;
    }
    try {
      const predicates = new relationalStore.RdbPredicates('mistake');
      predicates.equalTo('studentId', studentId);
      predicates.orderByDesc('createdAt');
      if (offset !== undefined && offset > 0) {
        predicates.offsetAs(offset);
      }
      if (limit !== undefined && limit > 0) {
        predicates.limitAs(limit);
      }
      const resultSet = await store.query(predicates);
      try {
        while (resultSet.goToNextRow()) {
          const m: Mistake | undefined = this.rowToMistake(resultSet);
          if (m !== undefined) {
            list.push(m);
          }
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return list;
  }

  async queryMistakeById(id: string): Promise<Mistake | undefined> {
    const op: string = 'queryMistakeById';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return undefined;
    }
    try {
      const predicates = new relationalStore.RdbPredicates('mistake');
      predicates.equalTo('id', id);
      const resultSet = await store.query(predicates);
      try {
        if (resultSet.goToFirstRow()) {
          return this.rowToMistake(resultSet);
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return undefined;
  }

  /**
   * 今日复习队列（T009/T034）：按学生过滤 + 每日上限截断 + 科目开关过滤。
   * subjects 为空数组视为「无启用科目」，返回空队列（设置真实生效）。
   */
  async queryTodayReviewMistakes(studentId: string, limit: number, subjects: Subject[]): Promise<Mistake[]> {
    const op: string = 'queryTodayReviewMistakes';
    const list: Mistake[] = [];
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return list;
    }
    if (subjects.length === 0) {
      return list;
    }
    try {
      const now = Date.now();
      const predicates = new relationalStore.RdbPredicates('mistake');
      predicates.equalTo('studentId', studentId);
      predicates.lessThanOrEqualTo('nextReviewDate', now);
      predicates.notEqualTo('status', MistakeStatus.MASTERED);
      const subjectValues: Array<relationalStore.ValueType> =
        subjects.map((s: Subject): relationalStore.ValueType => s as string);
      predicates.in('subject', subjectValues);
      predicates.orderByAsc('nextReviewDate');
      if (limit > 0) {
        predicates.limitAs(limit);
      }
      const resultSet = await store.query(predicates);
      try {
        while (resultSet.goToNextRow()) {
          const m: Mistake | undefined = this.rowToMistake(resultSet);
          if (m !== undefined) {
            list.push(m);
          }
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return list;
  }

  /** 删除错题与关联复习日志（T008：同事务，原子完成）。 */
  async deleteMistake(id: string): Promise<DbResult> {
    const op: string = 'deleteMistake';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return this.notReady(op);
    }
    return this.runInTransaction(op, async (): Promise<DbResult> => {
      const p1 = new relationalStore.RdbPredicates('mistake');
      p1.equalTo('id', id);
      await store.delete(p1);
      const p2 = new relationalStore.RdbPredicates('review_log');
      p2.equalTo('mistakeId', id);
      await store.delete(p2);
      return DbResult.ok();
    });
  }

  /** 状态聚合统计（T009）：SQL GROUP BY，替代全量加载内存过滤。 */
  async queryMistakeStats(studentId: string): Promise<MistakeStats> {
    const op: string = 'queryMistakeStats';
    const stats = new MistakeStats();
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return stats;
    }
    try {
      const resultSet = await store.querySql(
        'SELECT status AS st, COUNT(*) AS cnt FROM mistake WHERE studentId = ? GROUP BY status', [studentId]);
      try {
        while (resultSet.goToNextRow()) {
          const st: string = rs_col(resultSet, 'st');
          const cnt: number = rs_col_long(resultSet, 'cnt');
          stats.total += cnt;
          if (st === MistakeStatus.MASTERED) {
            stats.mastered = cnt;
          } else if (st === MistakeStatus.REVIEWING) {
            stats.reviewing = cnt;
          } else if (st === MistakeStatus.UNMASTERED) {
            stats.unmastered = cnt;
          }
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return stats;
  }

  /** 学科分布聚合（T009/T036）。 */
  async querySubjectDistribution(studentId: string): Promise<SubjectCount[]> {
    const op: string = 'querySubjectDistribution';
    const list: SubjectCount[] = [];
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return list;
    }
    try {
      const resultSet = await store.querySql(
        'SELECT subject AS sub, COUNT(*) AS cnt FROM mistake WHERE studentId = ? GROUP BY subject ORDER BY cnt DESC',
        [studentId]);
      try {
        while (resultSet.goToNextRow()) {
          const d = new SubjectCount();
          d.subject = rs_col(resultSet, 'sub');
          d.count = rs_col_long(resultSet, 'cnt');
          list.push(d);
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return list;
  }

  /**
   * 行读取失败整行跳过并记日志（T010），不再返回半初始化对象。
   */
  private rowToMistake(rs: relationalStore.ResultSet): Mistake | undefined {
    const m = new Mistake();
    try {
      m.id = rs_col(rs, 'id');
      m.studentId = rs_col(rs, 'studentId');
      m.imageUrl = rs_col(rs, 'imageUrl');
      m.ocrText = rs_col(rs, 'ocrText');
      m.ocrConfidence = rs_col_double(rs, 'ocrConfidence');
      m.isConfirmed = rs_col_long(rs, 'isConfirmed') === 1;
      m.subject = rs_col(rs, 'subject') as Subject;
      const tagStr: string = rs_col(rs, 'knowledgeTagIds');
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
      if (m.id.length === 0) {
        DbLog.warn('rowToMistake', 'row without id skipped');
        return undefined;
      }
      return m;
    } catch (e) {
      DbLog.error('rowToMistake', errText(e));
      return undefined;
    }
  }

  // ---------------------- review log ----------------------

  async insertReviewLog(log: ReviewLog): Promise<DbResult> {
    const op: string = 'insertReviewLog';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return this.notReady(op);
    }
    const value: Record<string, relationalStore.ValueType> = {
      'id': log.id, 'mistakeId': log.mistakeId, 'reviewTime': log.reviewTime,
      'gradingMethod': log.gradingMethod, 'inputMethod': log.inputMethod,
      'correct': log.correct ? 1 : 0, 'durationSeconds': log.durationSeconds,
      'pointsAwarded': log.pointsAwarded, 'clientOperationId': log.clientOperationId
    };
    return this.runWrite(op, async (): Promise<void> => {
      await store.insert('review_log', value);
    });
  }

  async queryReviewLogs(mistakeId: string): Promise<ReviewLog[]> {
    const op: string = 'queryReviewLogs';
    const list: ReviewLog[] = [];
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return list;
    }
    try {
      const predicates = new relationalStore.RdbPredicates('review_log');
      predicates.equalTo('mistakeId', mistakeId);
      predicates.orderByDesc('reviewTime');
      const resultSet = await store.query(predicates);
      try {
        while (resultSet.goToNextRow()) {
          list.push(rowToReviewLog(resultSet));
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return list;
  }

  /** 按学生批量查询复习日志（T009：导出用，join mistake 过滤 studentId）。 */
  async queryReviewLogsByStudent(studentId: string): Promise<ReviewLog[]> {
    const op: string = 'queryReviewLogsByStudent';
    const list: ReviewLog[] = [];
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return list;
    }
    try {
      const resultSet = await store.querySql(
        `SELECT r.id AS id, r.mistakeId AS mistakeId, r.reviewTime AS reviewTime,
         r.gradingMethod AS gradingMethod, r.inputMethod AS inputMethod, r.correct AS correct,
         r.durationSeconds AS durationSeconds, r.pointsAwarded AS pointsAwarded,
         r.clientOperationId AS clientOperationId
         FROM review_log r INNER JOIN mistake m ON r.mistakeId = m.id
         WHERE m.studentId = ? ORDER BY r.reviewTime ASC`, [studentId]);
      try {
        while (resultSet.goToNextRow()) {
          list.push(rowToReviewLog(resultSet));
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return list;
  }

  /** 复习统计聚合（T036）：SQL COUNT/SUM 替代全行遍历。 */
  async queryReviewStats(): Promise<ReviewStats> {
    const op: string = 'queryReviewStats';
    const stats = new ReviewStats();
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return stats;
    }
    try {
      const resultSet = await store.querySql(
        'SELECT COUNT(*) AS total, COALESCE(SUM(CASE WHEN correct = 1 THEN 1 ELSE 0 END), 0) AS correct FROM review_log');
      try {
        if (resultSet.goToFirstRow()) {
          stats.total = rs_col_long(resultSet, 'total');
          stats.correct = rs_col_long(resultSet, 'correct');
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return stats;
  }

  // ---------------------- knowledge tag / profile ----------------------

  async insertKnowledgeTag(tag: KnowledgeTag): Promise<DbResult> {
    const op: string = 'insertKnowledgeTag';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return this.notReady(op);
    }
    const value: Record<string, relationalStore.ValueType> = {
      'id': tag.id, 'subject': tag.subject, 'grade': tag.grade,
      'textbookVersion': tag.textbookVersion, 'name': tag.name,
      'parentTagId': tag.parentTagId
    };
    return this.runWrite(op, async (): Promise<void> => {
      await store.insert('knowledge_tag', value);
    });
  }

  async queryKnowledgeTags(subject?: Subject, grade?: Grade): Promise<KnowledgeTag[]> {
    const op: string = 'queryKnowledgeTags';
    const list: KnowledgeTag[] = [];
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return list;
    }
    try {
      const predicates = new relationalStore.RdbPredicates('knowledge_tag');
      if (subject !== undefined) {
        predicates.equalTo('subject', subject);
      }
      if (grade !== undefined) {
        predicates.equalTo('grade', grade);
      }
      const resultSet = await store.query(predicates);
      try {
        while (resultSet.goToNextRow()) {
          list.push(rowToKnowledgeTag(resultSet));
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return list;
  }

  async queryKnowledgeTagsByIds(ids: string[]): Promise<KnowledgeTag[]> {
    const op: string = 'queryKnowledgeTagsByIds';
    const list: KnowledgeTag[] = [];
    const store = await this.awaitStore(op);
    if (store === undefined || ids.length === 0) {
      return list;
    }
    try {
      const predicates = new relationalStore.RdbPredicates('knowledge_tag');
      predicates.in('id', ids);
      const resultSet = await store.query(predicates);
      try {
        while (resultSet.goToNextRow()) {
          list.push(rowToKnowledgeTag(resultSet));
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return list;
  }

  async queryKnowledgeProfiles(studentId: string): Promise<KnowledgeProfile[]> {
    const op: string = 'queryKnowledgeProfiles';
    const list: KnowledgeProfile[] = [];
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return list;
    }
    try {
      const predicates = new relationalStore.RdbPredicates('knowledge_profile');
      predicates.equalTo('studentId', studentId);
      const resultSet = await store.query(predicates);
      try {
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
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return list;
  }

  /** upsert 事务化（T008）。 */
  async upsertKnowledgeProfile(profile: KnowledgeProfile): Promise<DbResult> {
    return this.upsertKnowledgeProfiles([profile]);
  }

  /** 批量 upsert（T020/FR-021）：单事务一次性写入，画像重算不再逐条提交。 */
  async upsertKnowledgeProfiles(profiles: KnowledgeProfile[]): Promise<DbResult> {
    const op: string = 'upsertKnowledgeProfiles';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return this.notReady(op);
    }
    if (profiles.length === 0) {
      return DbResult.ok();
    }
    return this.runInTransaction(op, async (): Promise<DbResult> => {
      for (const profile of profiles) {
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
        const updated: number = await store.update(value, predicates);
        if (updated === 0) {
          await store.insert('knowledge_profile', value);
        }
      }
      return DbResult.ok();
    });
  }

  // ---------------------- student ----------------------

  async insertStudent(s: Student): Promise<DbResult> {
    const op: string = 'insertStudent';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return this.notReady(op);
    }
    const value: Record<string, relationalStore.ValueType> = {
      'id': s.id, 'parentId': s.parentId, 'nickname': s.nickname,
      'grade': s.grade, 'textbookVersion': s.textbookVersion,
      'region': s.region, 'school': s.school,
      'communityBrowseEnabled': s.communityBrowseEnabled ? 1 : 0,
      'communityShareEnabled': s.communityShareEnabled ? 1 : 0,
      'createdAt': s.createdAt
    };
    return this.runWrite(op, async (): Promise<void> => {
      await store.insert('student', value);
    });
  }

  async queryStudent(id: string): Promise<Student | undefined> {
    const op: string = 'queryStudent';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return undefined;
    }
    try {
      const predicates = new relationalStore.RdbPredicates('student');
      predicates.equalTo('id', id);
      const resultSet = await store.query(predicates);
      try {
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
          return s;
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return undefined;
  }

  async updateStudent(s: Student): Promise<DbResult> {
    const op: string = 'updateStudent';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return this.notReady(op);
    }
    const value: Record<string, relationalStore.ValueType> = {
      'nickname': s.nickname, 'grade': s.grade,
      'textbookVersion': s.textbookVersion,
      'region': s.region, 'school': s.school,
      'communityBrowseEnabled': s.communityBrowseEnabled ? 1 : 0,
      'communityShareEnabled': s.communityShareEnabled ? 1 : 0
    };
    const predicates = new relationalStore.RdbPredicates('student');
    predicates.equalTo('id', s.id);
    return this.runWrite(op, async (): Promise<void> => {
      await store.update(value, predicates);
    });
  }

  // ---------------------- points ----------------------

  async insertPointsLog(log: PointsLog): Promise<DbResult> {
    const op: string = 'insertPointsLog';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return this.notReady(op);
    }
    const value: Record<string, relationalStore.ValueType> = {
      'id': log.id, 'studentId': log.studentId,
      'actionType': log.actionType, 'points': log.points,
      'createdAt': log.createdAt
    };
    return this.runWrite(op, async (): Promise<void> => {
      await store.insert('points_log', value);
    });
  }

  async hasPointsLog(id: string): Promise<boolean> {
    const op: string = 'hasPointsLog';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return false;
    }
    try {
      const resultSet = await store.querySql('SELECT COUNT(*) AS cnt FROM points_log WHERE id = ?', [id]);
      try {
        if (resultSet.goToFirstRow()) {
          return rs_col_long(resultSet, 'cnt') > 0;
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return false;
  }

  /** 积分汇总（T009）：SQL SUM/COUNT；streakDays 由调用方注入真实值。 */
  async queryPointsSummary(studentId: string): Promise<PointsSummary> {
    const op: string = 'queryPointsSummary';
    const summary = new PointsSummary();
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return summary;
    }
    try {
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const resultSet = await store.querySql(
        `SELECT COALESCE(SUM(points), 0) AS total,
         COALESCE(SUM(CASE WHEN createdAt >= ? THEN points ELSE 0 END), 0) AS today
         FROM points_log WHERE studentId = ?`, [todayStart.getTime(), studentId]);
      try {
        if (resultSet.goToFirstRow()) {
          summary.totalPoints = rs_col_long(resultSet, 'total');
          summary.todayPoints = rs_col_long(resultSet, 'today');
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return summary;
  }

  async queryPointsLogs(studentId: string): Promise<PointsLog[]> {
    const op: string = 'queryPointsLogs';
    const list: PointsLog[] = [];
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return list;
    }
    try {
      const predicates = new relationalStore.RdbPredicates('points_log');
      predicates.equalTo('studentId', studentId);
      predicates.orderByDesc('createdAt');
      const resultSet = await store.query(predicates);
      try {
        while (resultSet.goToNextRow()) {
          const log = new PointsLog();
          log.id = rs_col(resultSet, 'id');
          log.studentId = rs_col(resultSet, 'studentId');
          log.actionType = rs_col(resultSet, 'actionType') as PointsActionType;
          log.points = rs_col_long(resultSet, 'points');
          log.createdAt = rs_col_long(resultSet, 'createdAt');
          list.push(log);
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return list;
  }

  /** 最近一次指定行为积分的本地日期（YYYY-MM-DD），用于 streak 按天幂等发放。 */
  async queryLastPointsActionDay(studentId: string, actionType: PointsActionType): Promise<string> {
    const op: string = 'queryLastPointsActionDay';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return '';
    }
    try {
      const resultSet = await store.querySql(
        'SELECT createdAt AS t FROM points_log WHERE studentId = ? AND actionType = ? ORDER BY createdAt DESC LIMIT 1',
        [studentId, actionType]);
      try {
        if (resultSet.goToFirstRow()) {
          return toLocalDateStr(rs_col_long(resultSet, 't'));
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return '';
  }

  // ---------------------- reminder settings ----------------------

  async queryReminderSettings(studentId: string): Promise<ReminderSettings> {
    const op: string = 'queryReminderSettings';
    const fallback: ReminderSettings = ReminderSettings.create(studentId);
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return fallback;
    }
    try {
      const predicates = new relationalStore.RdbPredicates('reminder_settings');
      predicates.equalTo('studentId', studentId);
      const resultSet = await store.query(predicates);
      try {
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
          return r;
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return fallback;
  }

  /** 提醒设置 upsert 事务化（T008）。 */
  async saveReminderSettings(r: ReminderSettings): Promise<DbResult> {
    const op: string = 'saveReminderSettings';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return this.notReady(op);
    }
    r.updatedAt = Date.now();
    return this.runInTransaction(op, async (): Promise<DbResult> => {
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
      const updated: number = await store.update(value, predicates);
      if (updated === 0) {
        await store.insert('reminder_settings', value);
      }
      return DbResult.ok();
    });
  }

  // ---------------------- analytics ----------------------

  async insertAnalyticsEvent(e: AnalyticsEvent): Promise<DbResult> {
    const op: string = 'insertAnalyticsEvent';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return this.notReady(op);
    }
    const value: Record<string, relationalStore.ValueType> = {
      'id': e.id, 'eventType': e.eventType, 'studentIdHash': e.studentIdHash,
      'platform': e.platform, 'properties': e.properties, 'occurredAt': e.occurredAt
    };
    return this.runWrite(op, async (): Promise<void> => {
      await store.insert('analytics_event', value);
    });
  }

  /** 指标汇总（T036）：基础计数走 GROUP BY，置信度/正确率仅拉取相关行。 */
  async queryMetricSummary(): Promise<MetricSummary> {
    const op: string = 'queryMetricSummary';
    const summary = new MetricSummary();
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return summary;
    }
    try {
      const countRs = await store.querySql(
        'SELECT eventType AS et, COUNT(*) AS cnt FROM analytics_event GROUP BY eventType');
      try {
        while (countRs.goToNextRow()) {
          const et: string = rs_col(countRs, 'et');
          const cnt: number = rs_col_long(countRs, 'cnt');
          if (et === 'capture') {
            summary.captureCount = cnt;
          } else if (et === 'review_submit') {
            summary.reviewSubmitCount = cnt;
          } else if (et === 'mastery_achieved') {
            summary.masteryAchievedCount = cnt;
          } else if (et === 'ocr_confirm') {
            summary.ocrConfirmCount = cnt;
          }
        }
      } finally {
        countRs.close();
      }

      let confSum: number = 0;
      let confCount: number = 0;
      const confRs = await store.querySql(
        'SELECT properties AS props FROM analytics_event WHERE eventType = ?', ['ocr_confirm']);
      try {
        while (confRs.goToNextRow()) {
          const parsed: number = parseConfidence(rs_col(confRs, 'props'));
          if (parsed >= 0) {
            confSum += parsed;
            confCount++;
          }
        }
      } finally {
        confRs.close();
      }
      summary.avgOcrConfidence = confCount > 0 ? confSum / confCount : 0;

      let reviewCorrect: number = 0;
      const revRs = await store.querySql(
        'SELECT properties AS props FROM analytics_event WHERE eventType = ?', ['review_submit']);
      try {
        while (revRs.goToNextRow()) {
          const props: string = rs_col(revRs, 'props');
          if (props.indexOf('"correct":true') >= 0) {
            reviewCorrect++;
          }
        }
      } finally {
        revRs.close();
      }
      summary.reviewAccuracy = summary.reviewSubmitCount > 0
        ? reviewCorrect / summary.reviewSubmitCount : 0;
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return summary;
  }

  // ---------------------- redemption ----------------------

  async insertRedemption(studentId: string, itemId: string, cost: number): Promise<DbResult> {
    const op: string = 'insertRedemption';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return this.notReady(op);
    }
    const value: Record<string, relationalStore.ValueType> = {
      'id': Date.now().toString(36) + Math.random().toString(36).substring(2, 6),
      'studentId': studentId, 'itemId': itemId, 'cost': cost,
      'redeemedAt': Date.now()
    };
    return this.runWrite(op, async (): Promise<void> => {
      await store.insert('redemption', value);
    });
  }

  async queryRedeemedItemIds(studentId: string): Promise<string[]> {
    const op: string = 'queryRedeemedItemIds';
    const ids: string[] = [];
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return ids;
    }
    try {
      const predicates = new relationalStore.RdbPredicates('redemption');
      predicates.equalTo('studentId', studentId);
      const resultSet = await store.query(predicates);
      try {
        while (resultSet.goToNextRow()) {
          ids.push(rs_col(resultSet, 'itemId'));
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return ids;
  }

  async queryTotalSpent(studentId: string): Promise<number> {
    const op: string = 'queryTotalSpent';
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return 0;
    }
    try {
      const resultSet = await store.querySql(
        'SELECT COALESCE(SUM(cost), 0) AS total FROM redemption WHERE studentId = ?', [studentId]);
      try {
        if (resultSet.goToFirstRow()) {
          return rs_col_long(resultSet, 'total');
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return 0;
  }

  // ---------------------- streak ----------------------

  /**
   * 活动日聚合（T009/T033）：录入（mistake.createdAt）∪ 复习（review_log.reviewTime），
   * 按本地日历日 DISTINCT，返回 ISO 日期串（YYYY-MM-DD）。
   */
  async queryActiveDays(studentId: string): Promise<string[]> {
    const op: string = 'queryActiveDays';
    const days: string[] = [];
    const store = await this.awaitStore(op);
    if (store === undefined) {
      return days;
    }
    try {
      const resultSet = await store.querySql(
        `SELECT DISTINCT date(m.createdAt / 1000, 'unixepoch', 'localtime') AS d FROM mistake m WHERE m.studentId = ?
         UNION
         SELECT DISTINCT date(r.reviewTime / 1000, 'unixepoch', 'localtime') AS d
         FROM review_log r INNER JOIN mistake m ON r.mistakeId = m.id WHERE m.studentId = ?
         ORDER BY d DESC`, [studentId, studentId]);
      try {
        while (resultSet.goToNextRow()) {
          days.push(rs_col(resultSet, 'd'));
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      DbLog.error(op, errText(e));
    }
    return days;
  }
}

function rowToReviewLog(rs: relationalStore.ResultSet): ReviewLog {
  const log = new ReviewLog();
  log.id = rs_col(rs, 'id');
  log.mistakeId = rs_col(rs, 'mistakeId');
  log.reviewTime = rs_col_long(rs, 'reviewTime');
  log.gradingMethod = rs_col(rs, 'gradingMethod') as GradingMethod;
  log.inputMethod = rs_col(rs, 'inputMethod') as InputMethod;
  log.correct = rs_col_long(rs, 'correct') === 1;
  log.durationSeconds = rs_col_long(rs, 'durationSeconds');
  log.pointsAwarded = rs_col_long(rs, 'pointsAwarded');
  log.clientOperationId = rs_col(rs, 'clientOperationId');
  return log;
}

function rowToKnowledgeTag(rs: relationalStore.ResultSet): KnowledgeTag {
  const tag = new KnowledgeTag();
  tag.id = rs_col(rs, 'id');
  tag.subject = rs_col(rs, 'subject') as Subject;
  tag.grade = rs_col(rs, 'grade') as Grade;
  tag.textbookVersion = rs_col(rs, 'textbookVersion') as TextbookVersion;
  tag.name = rs_col(rs, 'name');
  tag.parentTagId = rs_col(rs, 'parentTagId');
  return tag;
}

function toLocalDateStr(ts: number): string {
  const d = new Date(ts);
  const y: number = d.getFullYear();
  const m: number = d.getMonth() + 1;
  const day: number = d.getDate();
  return `${y}-${m < 10 ? '0' + m : m}-${day < 10 ? '0' + day : day}`;
}

function errText(e: Object): string {
  if (e instanceof Error) {
    return e.message;
  }
  return `${e}`;
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

/** 读列辅助（T006）：区分失败与默认值，失败记日志。 */
function rs_col(rs: relationalStore.ResultSet, col: string): string {
  try {
    const idx = rs.getColumnIndex(col);
    return rs.getString(idx);
  } catch (e) {
    DbLog.warn('readColumn', `column ${col} read failed: ${errText(e)}`);
    return '';
  }
}

function rs_col_long(rs: relationalStore.ResultSet, col: string): number {
  try {
    const idx = rs.getColumnIndex(col);
    return rs.getLong(idx);
  } catch (e) {
    DbLog.warn('readColumn', `column ${col} read failed: ${errText(e)}`);
    return 0;
  }
}

function rs_col_double(rs: relationalStore.ResultSet, col: string): number {
  try {
    const idx = rs.getColumnIndex(col);
    return rs.getDouble(idx);
  } catch (e) {
    DbLog.warn('readColumn', `column ${col} read failed: ${errText(e)}`);
    return 0;
  }
}

export const dbHelper = DatabaseHelper.getInstance();
