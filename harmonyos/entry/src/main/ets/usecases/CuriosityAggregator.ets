import {
  VoiceAskRecord, InterestInsight, VoiceAskStats,
  VoiceAskSubjectSummary, VoiceAskTopicSummary, VoiceAskTagSummary
} from '../models/VoiceAsk';
import { AiCuriosityReport } from '../services/AiService';

class CountEntry {
  key: string = '';
  count: number = 0;
}

/**
 * 本地先做确定性统计，AI 只负责叙事解释：
 * 这样兴趣数量、Top 标签不会被模型幻觉改写。
 */
export class CuriosityAggregator {
  static aggregate(records: VoiceAskRecord[]): VoiceAskStats {
    const stats = new VoiceAskStats();
    stats.total = records.length;
    const weekStart: number = Date.now() - 7 * 24 * 60 * 60 * 1000;
    const subjectCounts: CountEntry[] = [];
    const topicCounts: CountEntry[] = [];
    const tagCounts: CountEntry[] = [];
    for (const record of records) {
      if (record.createdAt >= weekStart) {
        stats.weekCount++;
      }
      CuriosityAggregator.increase(subjectCounts, record.subject);
      if (record.topic.length > 0) {
        CuriosityAggregator.increase(topicCounts, record.topic);
      }
      for (const tag of record.interestTags) {
        if (tag.length > 0) {
          CuriosityAggregator.increase(tagCounts, tag);
        }
      }
    }
    CuriosityAggregator.sortByCount(subjectCounts);
    CuriosityAggregator.sortByCount(topicCounts);
    CuriosityAggregator.sortByCount(tagCounts);
    stats.subjects = CuriosityAggregator.subjectSummary(subjectCounts);
    stats.topics = CuriosityAggregator.topicSummary(topicCounts);
    stats.tags = CuriosityAggregator.tagSummary(tagCounts);
    return stats;
  }

  static buildInsight(records: VoiceAskRecord[], report: AiCuriosityReport,
    periodStart: number, periodEnd: number, studentId: string): InterestInsight {
    const stats: VoiceAskStats = CuriosityAggregator.aggregate(records);
    let earliest: number = periodEnd;
    for (const record of records) {
      if (record.createdAt < earliest) {
        earliest = record.createdAt;
      }
    }
    const insight = new InterestInsight();
    insight.studentId = studentId;
    insight.periodStart = records.length > 0 ? earliest : periodStart;
    insight.periodEnd = periodEnd;
    insight.questionCount = stats.total;
    insight.topSubjects = CuriosityAggregator.subjectKeys(stats.subjects, 5);
    insight.topTopics = CuriosityAggregator.topicKeys(stats.topics, 8);
    insight.interestTags = CuriosityAggregator.tagKeys(stats.tags, 10);
    insight.trend = report.trend;
    insight.childSummary = report.childSummary;
    insight.parentSummary = report.parentSummary;
    insight.recommendedActivities = report.recommendedActivities;
    insight.generatedAt = Date.now();
    return insight;
  }

  private static increase(entries: CountEntry[], key: string): void {
    for (const entry of entries) {
      if (entry.key === key) {
        entry.count++;
        return;
      }
    }
    const entry = new CountEntry();
    entry.key = key;
    entry.count = 1;
    entries.push(entry);
  }

  private static sortByCount(entries: CountEntry[]): void {
    entries.sort((a: CountEntry, b: CountEntry): number => b.count - a.count);
  }

  private static subjectKeys(entries: VoiceAskSubjectSummary[], limit: number): string[] {
    const values: string[] = [];
    const max: number = Math.min(entries.length, limit);
    for (let i: number = 0; i < max; i++) {
      values.push(entries[i].subject);
    }
    return values;
  }

  private static topicKeys(entries: VoiceAskTopicSummary[], limit: number): string[] {
    const values: string[] = [];
    const max: number = Math.min(entries.length, limit);
    for (let i: number = 0; i < max; i++) {
      values.push(entries[i].topic);
    }
    return values;
  }

  private static tagKeys(entries: VoiceAskTagSummary[], limit: number): string[] {
    const values: string[] = [];
    const max: number = Math.min(entries.length, limit);
    for (let i: number = 0; i < max; i++) {
      values.push(entries[i].tag);
    }
    return values;
  }

  private static subjectSummary(entries: CountEntry[]): VoiceAskSubjectSummary[] {
    return entries.map((entry: CountEntry): VoiceAskSubjectSummary => {
      const item = new VoiceAskSubjectSummary();
      item.subject = entry.key;
      item.count = entry.count;
      return item;
    });
  }

  private static topicSummary(entries: CountEntry[]): VoiceAskTopicSummary[] {
    return entries.map((entry: CountEntry): VoiceAskTopicSummary => {
      const item = new VoiceAskTopicSummary();
      item.topic = entry.key;
      item.count = entry.count;
      return item;
    });
  }

  private static tagSummary(entries: CountEntry[]): VoiceAskTagSummary[] {
    return entries.map((entry: CountEntry): VoiceAskTagSummary => {
      const item = new VoiceAskTagSummary();
      item.tag = entry.key;
      item.count = entry.count;
      return item;
    });
  }
}
