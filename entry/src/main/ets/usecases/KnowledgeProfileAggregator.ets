import { Mistake } from '../models/Mistake';
import { KnowledgeProfile } from '../models/KnowledgeTag';
import { MistakeStatus, Trend } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { PerformanceMonitor } from '../services/PerformanceMonitor';

/**
 * 知识画像聚合（T020/FR-021）：
 * - 按学生走数据库过滤（queryMistakesByStudent），不再全表加载内存 filter；
 * - 已删/无错题标签的僵尸画像清零；
 * - 批量单事务 upsert。
 */
export class KnowledgeProfileAggregator {
  static async recomputeForStudent(studentId: string): Promise<void> {
    const studentMistakes: Mistake[] = await dbHelper.queryMistakesByStudent(studentId);

    const tagTotals: Map<string, number> = new Map();
    const tagMastered: Map<string, number> = new Map();

    for (const m of studentMistakes) {
      for (const tagId of m.knowledgeTagIds) {
        if (tagId.length === 0) {
          continue;
        }
        const t: number | undefined = tagTotals.get(tagId);
        tagTotals.set(tagId, (t !== undefined ? t : 0) + 1);
        if (m.status === MistakeStatus.MASTERED) {
          const mc: number | undefined = tagMastered.get(tagId);
          tagMastered.set(tagId, (mc !== undefined ? mc : 0) + 1);
        }
      }
    }

    const existing: KnowledgeProfile[] = await dbHelper.queryKnowledgeProfiles(studentId);
    const previousScores: Map<string, number> = new Map();
    for (const p of existing) {
      previousScores.set(p.knowledgeTagId, p.currentMasteryScore);
    }

    const now: number = Date.now();
    const pending: KnowledgeProfile[] = [];
    const seenTagIds: Set<string> = new Set<string>();

    const tagIds: string[] = Array.from(tagTotals.keys());
    for (const tagId of tagIds) {
      seenTagIds.add(tagId);
      const total: number = tagTotals.get(tagId) as number;
      const mastered: number = tagMastered.get(tagId) ?? 0;
      const score: number = total > 0 ? mastered / total : 0;
      pending.push(KnowledgeProfileAggregator.buildProfile(studentId, tagId, total, mastered, score,
        previousScores.get(tagId), now));
    }

    // 僵尸画像清零：库内存在画像但该学生已无对应标签错题（含标签被删）
    for (const p of existing) {
      if (!seenTagIds.has(p.knowledgeTagId)) {
        pending.push(KnowledgeProfileAggregator.buildProfile(studentId, p.knowledgeTagId, 0, 0, 0,
          previousScores.get(p.knowledgeTagId), now));
      }
    }

    const result = await dbHelper.upsertKnowledgeProfiles(pending);
    if (!result.success) {
      PerformanceMonitor.warn('recompute profiles failed: ' + result.reason);
    }
  }

  private static buildProfile(studentId: string, tagId: string, total: number, mastered: number,
    score: number, prev: number | undefined, now: number): KnowledgeProfile {
    const profile = new KnowledgeProfile();
    profile.id = `${studentId}_${tagId}`;
    profile.studentId = studentId;
    profile.knowledgeTagId = tagId;
    profile.totalMistakes = total;
    profile.masteredCount = mastered;
    profile.currentMasteryScore = score;
    let trend: Trend = Trend.STABLE;
    if (prev !== undefined) {
      if (score > prev + 0.001) {
        trend = Trend.IMPROVING;
      } else if (score < prev - 0.001) {
        trend = Trend.DECLINING;
      }
    }
    profile.trend = trend;
    profile.updatedAt = now;
    return profile;
  }
}
