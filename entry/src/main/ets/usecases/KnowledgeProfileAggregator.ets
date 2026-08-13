import { Mistake } from '../models/Mistake';
import { KnowledgeProfile } from '../models/KnowledgeTag';
import { MistakeStatus, Trend } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';

export class KnowledgeProfileAggregator {
  static async recomputeForStudent(studentId: string): Promise<void> {
    const allMistakes: Mistake[] = await dbHelper.queryMistakes();
    const studentMistakes: Mistake[] = allMistakes.filter((m: Mistake) => m.studentId === studentId);

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

    const tagIds: string[] = Array.from(tagTotals.keys());
    for (const tagId of tagIds) {
      const total: number = tagTotals.get(tagId) as number;
      const mastered: number = tagMastered.get(tagId) ?? 0;
      const score: number = total > 0 ? mastered / total : 0;

      const prev: number | undefined = previousScores.get(tagId);
      let trend: Trend = Trend.STABLE;
      if (prev !== undefined) {
        if (score > prev + 0.001) {
          trend = Trend.IMPROVING;
        } else if (score < prev - 0.001) {
          trend = Trend.DECLINING;
        }
      }

      const profile = new KnowledgeProfile();
      profile.id = `${studentId}_${tagId}`;
      profile.studentId = studentId;
      profile.knowledgeTagId = tagId;
      profile.totalMistakes = total;
      profile.masteredCount = mastered;
      profile.currentMasteryScore = score;
      profile.trend = trend;
      profile.updatedAt = Date.now();

      await dbHelper.upsertKnowledgeProfile(profile);
    }
  }
}
